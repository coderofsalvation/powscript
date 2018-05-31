# Syntax

<table style="">
  <thead>
    <tr>
      <th>What</th>
      <th>Powscript</th>
      <th>Bash output</th>
    </tr>
  </thead>
  <tbody>
  <tr>
    <td><b>functions</b></td>
    <td>
      <pre>
        <code>
foo( a, b )
  echo a=$a b=$b

foo one two
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
foo(){
  local a="$1"
  local b="$2"
  echo a="$a" b="$b"
}

foo one two
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>switch statement</b></td>
    <td>
      <pre>
        <code>
switch $foo
  case [0-9]*
    echo "bar"
  case *
    echo "foo"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
case $foo in
  [0-9]*)
    echo "bar"
    ;;
  *)
    echo "foo"
    ;;
esac
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>easy if statements</b></td>
    <td>
      <pre>
        <code>
if $i is "foo"
  echo "foo"
else
  echo "bar"
</code>
<code>
if not $j is "foo" and $x is "bar"
  if $j is "foo" or $j is "xfoo"
    if $j > $y and $j != $y or $j >= $y
      echo "foo"
</code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
if [[ "$i" == "foo" ]]; then
  echo "foo"
else
  echo "bar"
fi

if [[ ! "$j" == "foo" && "$x" == "bar" ]]; then
  if [[ "$j" == "foo" || "$j" == "xfoo" ]]; then
    if [[ "$j" -gt "$y" && "$j" -ne "$y" || "$j" -ge "$y" ]]; then
      echo "foo"
    fi
  fi
fi
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>associative array</b></td>
    <td>
      <pre>
        <code>
foo={}
foo["bar"]="a value"

for k,v in foo
  echo k=$k
  echo v=$v

echo $foo["bar"]
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
declare -A foo
foo["bar"]="a value"

for k in "${!foo[@]}"; do
  v="${foo[$k]}"
  echo k="$k"
  echo v="$v"
done

echo "${foo["bar"]}"
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>indexed array</b></td>
    <td>
      <pre>
        <code>
bla=[]
bla[0]="foo"
bla+="push value"

for i in bla
  echo bla=$i

echo $bla[0]
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
declare -a bla
bla[0]="foo"
bla+=("push value")

for i in "${bla[@]}"; do
  echo bla="$i"
done

echo "${bla[0]}"
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>read file line by line (shared scope)</b></td>
    <td>
      <pre>
        <code>
for line from $selfpath/foo.txt
  echo "->"$line
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
  while IFS="" read -r line; do
    echo "->"$line
  done < $1
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>regex</b></td>
    <td>
      <pre>
        <code>
if $f match ^([f]oo)
  echo "foo found!"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# extended pattern matching
# (google 'extglob' for more

if [[ "$f" =~ ^([f]oo) ]]; then
  echo "foo found!"
fi
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>require module</b></td>
    <td>
      <pre>
        <code>
# include bash- or powscript
# at compiletime (=portable)
require 'mymodule.pow'
        </code>
        <code>
# include remote bashscript
# at runtime
source foo.bash
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>empty / isset checks</b></td>
    <td>
      <pre>
        <code>
bar()
  if isset $1
    echo "no argument given"
  if not empty $1
    echo "string given"
        <code>
        </code>
foo "$@"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
foo(){
  if [[ "${#1}" == 0 ]]; then
    echo "no argument given"
  fi
  if [[ ! "${#1}" == 0 ]]; then
    echo "string given"
  fi
}
        </code>
        <code>
foo "$@"
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>mappipe unwraps a pipe</b></td>
    <td>
      <pre>
        <code>
myfunc()
  echo "value=$1"
        </code>
        <code>
echo -e "foo\nbar\n" | mappipe myfunc
        </code>
        <code>
# outputs: 'value=foo' and 'value=bar'
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>easy math</b></td>
    <td>
      <pre>
        <code>
math '9 / 2'
math '9 / 2' 4
# outputs: '4' and '4.5000'
# NOTE: the second requires bc
# to be installed for floatingpoint math
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>Easy async</b></td>
    <td>
      <pre>
        <code>
myfunc()
  sleep 1s
  echo "one"
        </code>
        <code>
await myfunc 123 then
  echo "async done"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: one
#          async done
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>Easy async pipe</b></td>
    <td>
      <pre>
        <code>
myfunc()
  sleep 1s
  echo "one"
        </code>
        <code>
await myfunc 123 then |
  cat -
        </code>
        <code>
when done
  echo "async done"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: one
#          async done
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>Easy async pipe (per line)</b></td>
    <td>
      <pre>
        <code>
myfunc()
  sleep 1s
  echo "one"
  echo "two"
        </code>
        <code>
await myfunc 123 then for line
  echo "line: $*"
when done
  echo "async done"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: line: one
#          line: two
#          async done
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>JSON decode</b></td>
    <td>
      <pre>
        <code>
json={}
cat package.json | json_decode json
echo $json['repository.url']
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: git+https://coderofsalvation@github.com/coderofsalvation/powscript.git
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>FP: curry</b></td>
    <td>
      <pre>
        <code>
myfunc()
  echo "1=$1 2=$2"
        </code>
        <code>
curry curriedfunc abc
echo -e "foo\nbar\n" | mappipe curriedfunc
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: '1=abc 2=foo' and '1=abc 2=bar'
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>FP: array values, keys</b></td>
    <td>
      <pre>
        <code>
foo={}
foo["one"]="foo"
foo["two"]="bar"
map foo keys   # prints key per line
map foo values # prints value per line
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>FP: map</b></td>
    <td>
      <pre>
        <code>
printitem()
  echo "key=$1 value=$2"
        </code>
        <code>
foo={}
foo["one"]="foo"
foo["two"]="bar"
map foo printitem
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>FP: pick</b></td>
    <td>
      <pre>
        <code>
foo={}
bar={}
foo["one"]="foo"
bar["foo"]="123"
map foo values | unpipe pick bar
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: '123'
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td><b>FP: compose</b></td>
    <td>
      <pre>
        <code>
funcA()
  echo "($1)"
        </code>
        <code>
funcB()
  echo "|$1|"
        </code>
        <code>
compose decorate_string funcA funcB
decorate_string "foo"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: '(|foo|)'
        </code>
      </pre>
    </td>
  </tr>

  </tbody>
</table>

# Predefined vars

| **description**           | **variable name** | **example**                        |
|---------------------------|-------------------|------------------------------------|
| script path               | $selfpath         | for line in $selfpath/foo.txt      |
| current working directory | $self             | ls $self/*                         |
| temporary file            | $tmpfile          | echo '{foo:"bar"}' > $tmpfile.json |

