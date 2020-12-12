#!/bin/bash

# shamelessly stolen from Michael Sevilla

FNAME=$(basename "$(pwd)")

cleanup() 
{
    echo "Cleaning up..."
    {
        cd src || exit
        rm -r _minted-src 
        rm -- *.aux *.bbl *.blg *.synctex.gz 
        rm -- *.log ../*.log *.out 
        cd - || exit
    } >> /dev/null 2>&1
}
cleanup
rm "${FNAME}.pdf" >> /dev/null 2>&1

echo "Pull recent image..."
docker pull petewilcox/texlive:latest > build.log

# chktex errors we want to ignore
err_ignore=(
    -n22
    -n36
    -n30
    -n13
    -n17
    -n38
    -n2
    -n44
    -n26
    -n10
    -n12
    )

echo "Linting..."
for f in src/*.tex; do
    echo "- $f"
    docker run --rm \
        --name latex \
        -v "$(pwd)"/:/mnt \
        --entrypoint=/bin/bash \
        petewilcox/texlive:latest -c \
        "chktex -eall -I ${err_ignore[*]} /mnt/$f" &> chktex.log

    grep "No errors printed" chktex.log >> /dev/null

    # shellcheck disable=SC2181
    if [  $? != 0 ]; then
        echo "ERROR: linter failed, check chktex.log!"
        exit 1
    fi
done

echo "Building..."
cmd="pdflatex -synctex=1 -interaction=nonstopmode -shell-escape src"
docker run --rm \
    --name latex \
    -v "$(pwd)"/:/mnt \
    -w /mnt/src \
    --entrypoint=/bin/bash \
    petewilcox/texlive:latest -c \
    "$cmd; $cmd; $cmd" &> build.log

# shellcheck disable=SC2181
if [ $? != 0 ]; then
    echo "ERROR: build pdf failed, check build.log!"
    exit 1
fi

mv src/src.pdf "${FNAME}".pdf
cleanup
echo "SUCCESS"
