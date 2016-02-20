write shellscript in a powful way!

\![Build Status](https://travis-ci.org/coderofsalvation/powscript.svg?branch=master)

## Usage
    
    $ powscript myscript.pow                        # run directly
    $ powscript --compile myscript.pow > myscript   # compile to bashscript

## Features

* syntactic sugar: less { ! [[ @ ]] || ~ and so on
* safetynets: automatic quoting, halt on error
* easy declaring- and iterating over arrays
* 100% bash:'zero'-dependency solution (no installation, compilation using 3rd party software)

## Language

<table style="width:100%">
  <tr>
    <th>What</th>
    <th>Powscript</th>
    <th>Compiles to bash</th>
  </tr>

  <tr>
    <td>switch statement</td>
    <td>
      <pre>
        <code>
switch $foo
  case 0-9
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
  0-9)
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
    <td>if statement</td>
    <td>
      <pre>
        <code>
if $i is "foo"
  echo "foo" 

if not $j is "foo" and $x is "bar"
  if $j is "foo" or $j is "xfoo"
    echo "foo!" 
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
if [[ "$i" == "foo" then ]]; then
  echo "foo" 
fi

if [[ ! "$j" == "foo" && "$x" is "bar"]]; then
  if [[ "$j" == "foo" || "$j" is "xfoo"]]; then
    echo "foo!" 
  fi
fi
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td>associative array</td>
    <td>
      <pre>
        <code>
foo={}
foo["bar"]="a value"

for k,v of foo
  echo k=$k
  echo v=$v
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
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td>indexed array</td>
    <td>
      <pre>
        <code>
bla=[]
bla[0]="foo"
bla[]="push value"

for i in bla
  echo bla=$i
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
        </code>
      </pre>
    </td>
  </tr>

  <tr>
    <td>regex</td>
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

</table>

## Wiki

* [Similar projects](https://github.com/coderofsalvation/powscript/wiki/Similar-projects)
