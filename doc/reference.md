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
    <td align="center"><b>Functions</b></td>
    <td>
      <pre>
        <code>
foo(a b)
  echo a=$a b=$b
        </code>
        <code>
foo one two
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
f() {
local a="${1}" b="${2}"
echo a="${a}" b="${b}"
}
        </code>
        <code>
foo one two
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>Switch statement</b></td>
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
case "${foo}" in
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
    <td align="center"><b>Easy if statements</b></td>
    <td>
      <pre>
        <code>
if $i is "foo"
  echo "foo"
else
  echo "bar"
</code>
<code>
if not false and true
  if true or false
    echo "foo"
        </code>
        <code>
if $x > $y
  echo "bar"
elif $a < $b
  echo "baz"
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
        </code>
        <code>
if ! false && true; then
  if true || false; then
    echo 10
  fi
fi
        </code>
        <code>
if [[ "$x" -gt "$y" ]]; then
  echo "bar"
elif [[ "$a" -lt "$b" ]]; then
  echo "baz"
fi
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>Associative arrays</b></td>
    <td>
      <pre>
        <code>
foo={}
foo["bar"]="a value"
        </code>
        <code>
for k,v of foo
  echo k=$k
  echo v=$v
        </code>
        <code>
echo $foo["bar"]
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
declare -A foo
foo["bar"]="a value"
        </code>
        <code>
for k in "${!foo[@]}"; do
  v="${foo[$k]}"
  echo k="$k"
  echo v="$v"
done
        </code>
        <code>
echo "${foo["bar"]}"
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>Indexed array</b></td>
    <td>
      <pre>
        <code>
bla=[]
bla[0]="foo"
bla@="push value"
        </code>
        <code>
for i of bla
  echo bla=$i
        </code>
        <code>
echo $bla[0]
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
declare -a bla
bla[0]="foo"
bla[${#bla}]="push value"
        </code>
        <code>
for i in "${bla[@]}"; do
  echo bla="$i"
done
        </code>
        <code>
echo "${bla[0]}"
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>Read file line by line (shared scope)</b></td>
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
    <td align="center"><b>Regex</b></td>
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
# (google 'extglob' for more)
        </code>
        <code>
if [[ "$f" =~ ^([f]oo) ]]; then
  echo "foo found!"
fi
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>Requiring modules</b></td>
    <td>
      <pre>
        <code>
# compile and include
# powscript file
require 'mymodule.pow'
        </code>
        <code>
# source works at runtime
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
    <td align="center"><b>empty / isset checks</b></td>
    <td>
      <pre>
        <code>
bar()
  if empty $1
    echo "no argument given"
  if isset $1
    echo "string given"
        </code>
        <code>
foo "$@"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
foo(){
  if [ -z "${1}" ]; then
    echo "no argument given"
  fi
  if [ -n "${#1}" ]; then
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
    <td align="center"><b>mappipe unwraps a pipe</b></td>
    <td>
      <pre>
        <code>
fn()
  echo "value=$1"
        </code>
        <code>
echo -e "a\nb\n" | mappipe fn
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: value=a
#          value=b
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>Easy math</b></td>
    <td>
      <pre>
        <code>
math (9 / 2)
math (9 / 2) 4
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: '4' and '4.5000'
# NOTE: floating point math
#       requires bc
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>Easy async</b></td>
    <td>
      <pre>
        <code>
fn()
  sleep 1s
  echo "one"
        </code>
        <code>
await fn 123 then
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
    <td align="center"><b>Easy async pipe</b></td>
    <td>
      <pre>
        <code>
fn()
  sleep 1s
  echo "one"
        </code>
        <code>
await fn 123 then |
  cat -
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
    <td align="center"><b>Easy async pipe (per line)</b></td>
    <td>
      <pre>
        <code>
fn()
  sleep 1s
  echo "one"
  echo "two"
        </code>
        <code>
await fn 123 then for line
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
    <td align="center"><b>JSON decode</b></td>
    <td>
      <pre>
        <code>
obj={}
json='{"a": {"b": "c"}}'
        </code>
        <code>
echo "$json" | json_decode obj
echo $obj['a-b']
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: c
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>FP: curry</b></td>
    <td>
      <pre>
        <code>
fn(a b)
  echo "1=$a 2=$b"
        </code>
        <code>
curry fnc a
echo -e "b\nc\n" | mappipe fnc
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: 1=a 2=b
#          1=a 2=c
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>FP: array values, keys</b></td>
    <td>
      <pre>
        <code>
foo={}
foo["one"]="foo"
foo["two"]="bar"
map foo keys
map foo values
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: one
#          two
#          foo
#          bar
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>FP: map</b></td>
    <td>
      <pre>
        <code>
printitem(k v)
  echo "key=$k value=$v"
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
    <td align="center"><b>FP: pick</b></td>
    <td>
      <pre>
        <code>
foo={}
bar={}
foo["one"]="foo"
bar["foo"]="123"
map foo values |\
  mappipe pick bar
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: 123
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td align="center"><b>FP: compose</b></td>
    <td>
      <pre>
        <code>
fnA(x)
  echo "($x)"
        </code>
        <code>
fnB(x)
  echo "|$x|"
        </code>
        <code>
compose decorate fnA fnB
decorate "foo"
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
# outputs: (|foo|)
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

