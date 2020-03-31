Font Test Markup Language
=========================

Font Test Markup Language (ftml) is a file format for specifying the content and structure of font test data. It is designed to support complex test data, such as strings with specific language tags or data that should presented with certain font features activated. It also allows for indication of what portions of test data are in focus and which are only present to provide context.

# File Format
There are four main elements around which the file format is structured:

1. **Root** - Defines file format version
2. **Header** - Sets general parameters for how tests are styled and presented
3. **Test groups** - Groups test for presentation purposes
4. **Tests** - Contains test data

For validation purposes, sub elements of an element always occur in the order listed for them in this document. It is incidental that the order happens to also be alphabetic, but may not remain that way.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ftml version="1.0">
  <head>
    <!-- define general parameters here -->
    <styles>
      <!-- define optional styles here -->
      <style../>
    </styles>
  </head>
  <testgroup label="main">
    <!-- define tests here -->
    <test label="required">
      <!-- define test data and metadata here -->
    </test>
    <test../>
  </testgroup>
  <testgroup../>
</ftml>
```
## 1. Root `ftml`
The root **ftml** element has the following attributes:

- **version**: The version of the file format. This attribute is required and is currently "1.0".

The **ftml** element takes a required **head** element and one or more **testgroup** elements as direct children.

## 2. Header `head`
The **head** element contains shared information across all the tests in the file. The information held here gives concrete styling for use by presentation tools that have no other information to override the information stored here. This element is required. To allow for easy extensibility, applications are required to preserve all elements in the header even if they do not understand them. Additional optional elements added to the header do not require a version increase.

The **head** element takes **comment**, **fontscale**, **fontsrc**, **styles**, **title** and **widths** elements as direct children.

### comment
A **comment** element may be used within **head** to provide descriptive text about the whole ftml document. The text value of this element specifies the comment text. This element is optional and, if present, must not be empty.

### fontscale
This specifies the relative scaling that should be applied to text in the given font when rendering with a typical Western font like Times. The text child of this element must contain a positive integer and will be interpreted as a percentage. This element is optional and the default scale is 100 percent.

### fontsrc
This specifies a font source that may be used to render the tests. This mechanism is not intended to meet all needs, especially for projects that have more than one weight or style of font, so ftml consumers are permitted to implement their own mechanism for font selection.

The element has a text child which is in the same format as [`src:` parameter of the css `@font-face` attribute](http://www.w3.org/TR/css3-fonts/#src-desc). Although the `src:` parameter supports multiple font sources in the CSS standard, for the purposes of FTML it is recommended that only one `src:` be specified. The CSS standard allows multiple `src:` for fall-back purposes which would rarely make sense in a testing environment. Note that some FTML processors will only see the first `src:`.

This element is optional, and there may be more than one of them.

### styles
Different tests may be rendered using different styling. The primary concern here is the use of font feature and language information. The styles element contains a list of style elements that specify how text of a given style name should be rendered.

The **styles** element is optional since tests do not need to be associated with a style. If present, the
**styles** element takes one or more **style** elements as direct children.

#### style

Each **style** has a number of attributes:

- **feats**: This is a comma-separated list of id-value pairs (with id enclosed in single quotes followed by a space and the value) which specify the font features to be used for this string. This format is identical to [css font-feature-settings property](http://www.w3.org/TR/css3-fonts/#font-feature-settings-prop) except that a value is required even for _boolean_ features (for example: `feats="'smcp' 1, 'swsh' 2"`). The list is minimal (that is only those features that differ from the defaults set by the language are specified) and stored with ids in alphabetical order, for canonicalization purposes. This attribute is optional.
- **lang**: This is a language tag, in HTML (i.e. [BCP47](http://www.ietf.org/rfc/bcp/bcp47.txt)) format. This attribute is optional.
- **name**: This specifies the name of the style being defined. Because the name of the style can be used as CSS style indentifier, the attribute value must not include whitespace. This attribute is required.

The **style** elements are optional.

### title
The **title** element may be used to provide a title for the ftml document. The element has a text child specifying the title text. This element is optional and, if present, must not be empty.

### widths
This element describes table and column widths. Each width may be specified in absolute terms using a width followed by any of the following units of measurement: **em** specifies a width in terms of the font size; **in** which is an absolute width in inches. Alternatively a width may be a width weight, specified by a number followed by a **%**. The final width of the column is the spare space after all fixed width columns are calculated divided by the sum of all the weights and multiplied by the particular weight of the column.

The attributes correspond to predefined identified columns:

- **comment**: Specifies the width for the comment column.
- **label**: Specifies the width of the column used to present the test label.
- **string**: Specifies the width of the column for the rendered test strings.
- **stylename**: Specifies the width of the column giving the styling class for the test.
- **table**: Specifies overall width of the table

Note that this element is merely a hint. An application is free to display tests however it wants. The element is optional and all attributes are optional.

## 3. Test Groups `testgroup`
Tests are grouped into one or more **testgroup** elements. No test may exist outside of a test group. A **testgroup** is either a list of zero or more **test**s or, if desired, a list of sub **testgroup**s. Although, until such time as a real use-case for deeper nesting is demonstrated, only one level of nesting is permitted (i.e. the outer test group and inner test group).

This specification does not attach semantic meaning to such nesting, and FTML consumers are free to utilize or display such nesting as they desire. One example use, and the one that initially drove the request, is to display tests from an inner group as columns in a table.

A **testgroup** has the following attributes:

- **background**: Specifies the default background colour for the entire testgroup. The colour is specified in the form #xxyyzz where x, y and z are hex digits and the value xx specifies the red value, yy the green value and zz the blue value. This attribute is optional.
- **label**: A textual label for the group by which it is identified. This is a required attribute.

A **testgroup** takes a single optional **comment** at the start.

### comment
A **comment** element may be used to provide descriptive information about a test group. The text child of this element specifies the comment text. This element is optional and, if present, must not be empty.

## 4. Tests `test`
A **test** element contains the text data and parameters for a specific test. It has the following attributes:

- **background**: Specifies the background colour for the test. The colour is specified in the form `#xxyyzz` where x, y and z are hex digits and the value xx specifies the red value, yy the green value and zz the blue value. This attribute is optional.
- **label**: Identifying label for the test. This attribute is required.
- **rtl**: Set to `True` if the test is to be run with the paragraph direction set to right to left. This attribute is optional and applied only to the string.
- **stylename**: Styling class that references a **style** in the header. This attribute is optional and is applied only to the string.

This element is optional. A test contains a single string element and an optional comment element.

### comment
A **comment** element may be used to supply descriptive text for a test. The text value of this element specifies the comment text. This element is optional and, if present, must not be empty.

### string
The **string** element contains the text data for the test. Optionally, string elements can have **em** subelements. The test data is defined to be the concatenation of the text children of the string and any **em** subelements.

Within the test data, the notation `\u` followed by 4, 5 or 6 hexadecimal digits is supported for representing the Unicode character that corresponds to that hexadecimal value. FTML processors must preserve `\u` notation except during processing needed for rendering. FTML producers need to be aware that there is no delimiter on this sequence (other than the maximum of 6 digits). Therefore if a character to be encoded using this notation is followed immediately by a character that could be interpreted as a hexadecimal digit, the producer should pad the digit sequence with leading zeros to bring its length to 6 digits.

NB: The **string** element is the only element in ftml that permits both text and subelement children.

This element is required and may be empty.

#### em
The **em** subelement of string identifies those portions of the test data that are the logical focus for the test. If **em** elements are present, test data outside of the **em** elements is considered context and FTML consumers might, for example, use colour to de-emphasize the context data. This element is optional.

# Canonicalization
To facilitate version control, the following canonicalization of the layout of the XML is strongly encouraged.

* All the attributes of an element shall be on the same line as the tag and be listed in alphabetical order of attribute name. Exception: in the XML initial [processing instructions](http://www.w3.org/TR/WD-xml-961114.html#sec2.5) the conventional order will be used.
* Inline elements start and end on the same line as their parent and immediately adjacent to any sibling text children. The following are designated as inline elements:
    * **em**
* With the exception of inline elements:
    * Indentation of child elements is 2 spaces and child elements start on the following line after the opening parent element. The closing tag for the parent is on a line after the last child element with the same indentation as the opening tag.
    * Child elements are sorted by tag, according to the order listed in this document.
    * In the cases where multiple elements of the same tag may exist:
         * The **style** elements are sorted by their name attribute
         * The order of all others, including **testgroup** and **test** elements, and any unrecognized elements within the head element, is preserved
* There are no blank lines between elements.
* text children occur immediately following the parent element. The closing tag immediately follows the last character of the text.
* Text is stored in UTF-8 with no entities other than as required by xml (i.e. `<` and & are stored as entities in text, and `>`, `&` and `"` are stored as entities in attributes).
* Attributes use double quotes.
* All optional empty elements must be removed if they have no attributes. Empty elements use the empty element tag with no space before `/>`.
* **feats** attributes have their various features sorted alphabetically by feature tag.
* Empty attributes are not present.
* Colour values are represented using lower case hex digits.

# Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="TestStyleSheet.xsl"?>
<ftml version="1.0">
  <head>
    <fontscale>150</fontscale>
    <fontsrc>url(Padauk.ttf)</fontsrc>
    <styles>
      <style feats="’hsln’ 1" lang="kht" name="other"/>
    </styles>
    <widths comment="30%" label="6em" string="70%"/>
  </head>
  <testgroup label="main">
    <test label="padauk3">
      <comment>changed features</comment>
      <string>သင်္ချိုင်း</string>
    </test>
    <test label="test1" stylename="other">
      <string>ကှု</string>
    </test>
  </testgroup>
</ftml>
```

# Tools
There are a number of .xsl tools in this repository which are documented in the FTML.md file.

Additionally a python tool to generate a LibreOffice writer document from FTML input is available as part of [pysilfont].

[pysilfont]: https://github.com/silnrsi/pysilfont
