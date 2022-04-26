for f in *.yaml; do
    dir=`echo "$f"|sed 's/-.*//'`
    file=`echo "$f"|sed 's/.*-//'`
    mv "$f" "$dir/$file"
done

