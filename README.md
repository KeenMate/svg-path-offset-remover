# SvgPathOffsetRemover

Application used for moving paths extracted from SVGs into 0,0 position (top-left corner of sprite to be at 0,0).
It now serves for single purpose and screnario - it is quite limited at the moment.

It now also only parses M (move absoulute), L (Line) and V (Vertical line) commands inside of d attribute of path element.

# Usage

It expects file path with content (or content directly) that is of following structure:
```xml
<svg>
	<path d="VALUE_FOR_PROCESSING" ...other unharmed attrs />
	<path d="VALUE_FOR_PROCESSING" ...other unharmed attrs />
	...
	<!-- other unharmed elements -->
</svg>
```

## Examples of running the code

To process svg file and get result to STDOUT
`mix run svg_path_offset_remover.ex input.svg`

To process svg file and save result to file
`mix run svg_path_offset_remover.ex --save-path output.svg input.svg`

To process svg text and save result to file
`mix run svg_path_offset_remover.ex --save-path output.svg --content "<svg><path\ d=\"...\"\ /></svg>"`

