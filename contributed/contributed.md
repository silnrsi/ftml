# Contributed ftml-related files

## `ftml.xsl` and `ftml-smith.xsl`

These two xsl stylesheet files are commonly used in SIL font projects to render an FTML into html, e.g., for display in a browser. 

NB: neither of these support nested `testgroup` elements.

`ftml.xsl` supports:
- multiple `fontsrc` elements:
    - each in its own column
    - `@label` attribute used as the header for each column
- SMP as well as BMP characters using `\u` notation

`ftml-smith` supports a single parameterized `fontsrc` as needed for `smith`-based testing of ftml, usually implemented in the `wscript` using:
```
ftmlTest('tools/ftml-smith.xsl')
```
and then initiated by including the target `ftml` or `test` on the smith commandline, e.g.:
```
smith build ftml
```
