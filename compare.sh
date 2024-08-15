#!/bin/bash
#

LOONGREPO=$HOME/extra
ARCHREPO=$HOME/archrepos/extra
LOONGPACKAGE=$HOME/loongarch-packages/extra

# when loong's rel is bigger, try select another tag
find_tag() {
    VER=${1%-*}
    # select the tag with largest rel value
    TAG=$(git tag -l $VER-* |sort -V |tail -n 1)
    REL=${TAG##*-}
    cd $LOONGREPO/$2
    sed -i "s/^pkgrel=.*/pkgrel=$REL/" PKGBUILD
    cd $ARCHREPO/$2
    # text file "fails" will contain failed packages
    pkgctl repo switch $TAG || echo $2-$1 >> $LOONGPACKAGE/fails
}

cd $LOONGREPO
for i in *; do
    cd $LOONGREPO/$i
    EPOCH=$(source PKGBUILD; echo $epoch)
    PKGVERREL=$(source PKGBUILD; echo $pkgver-$pkgrel)
    if [ ! -d $ARCHREPO/$i ]; then
        cd $ARCHREPO
        pkgctl repo clone --protocol https $i || echo $i-$PKGVERREL >> $LOONGPACKAGE/loongonly
        sleep 5
    fi
    # failed to clone
    if [ ! -d $ARCHREPO/$i ]; then
        continue
    fi
    cd $ARCHREPO/$i
    if [ -z "$EPOCH" ]; then
       pkgctl repo switch $PKGVERREL || find_tag $PKGVERREL $i
    else
       pkgctl repo switch $EPOCH-$PKGVERREL || find_tag $EPOCH-$PKGVERREL $i
    fi
    cp $LOONGREPO/$i/* . -a
    git diff > loong.patch
    if [ ! -s loong.patch ]; then
        pwd
        rm loong.patch
    else
        mkdir -p $LOONGPACKAGE/$i
        mv loong.patch $LOONGPACKAGE/$i
        for file in `git ls-files --others --exclude-standard`; do
            mv $file $LOONGPACKAGE/$i/
        done
        echo "VER=$PKGVERREL" > $LOONGPACKAGE/$i/spec
    fi
    pkgctl repo switch main -f
done

