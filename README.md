write shellscript in a powful way!

\![Build Status](https://travis-ci.org/coderofsalvation/powscript.svg?branch=master)

## Usage
    
    $ powscript myscript.pow                        # run directly
    $ powscript --compile myscript.pow > myscript   # compile to bashscript

## Features

* no more syntactic noise
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
for i in {0..10}
  bla[$i]=$i;
        </code>
      </pre>
    </td>
    <td>
      <pre>
        <code>
declare -a bla
for i in {0..10}; do
  bla[$i]="$i";
done
        </code>
      </pre>
    </td>
  </tr>
</table>

## Wiki

* [Similar projects](https://github.com/coderofsalvation/powscript/wiki/Similar-projects)
