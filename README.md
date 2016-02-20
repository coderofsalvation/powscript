write shellscript in a powful way!

\![Build Status](https://travis-ci.org/coderofsalvation/powscript.svg?branch=master)

## Usage
    
    $ powscript myscript.pow                        # run directly
    $ powscript --compile myscript.pow > myscript   # compile to bashscript

## Features

* syntactic sugar: less { ! [[ @ ]] and so on
* safetynets: automatic quoting
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
declare -a   bla
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
declare -A   foo
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
</table>

## Wiki

* [Similar projects](https://github.com/coderofsalvation/powscript/wiki/Similar-projects)
