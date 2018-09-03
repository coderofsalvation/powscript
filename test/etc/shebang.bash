file=$(mktemp -u).powscript
./powscript -c <(echo "echo 'hello world (bash)'") -o $file.bash
./powscript -c <(echo "echo 'hello world (sh)'") --to sh -o $file.sh

chmod +x $file.bash
chmod +x $file.sh

$file.bash
$file.sh

rm $file.bash
rm $file.sh
