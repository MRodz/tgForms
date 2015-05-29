# tgForms

> Generate HTML forms from RDF/Turtle

tgForms is a JavaScript library to generate HTML forms from RDF/Turtle. It was originally written for the use with [TextGrid](http://textgrid.de).


## Installation

If you have [node.js](http://nodejs.org) and [Bower](http://bower.io) installed, you can get the latest development version of tgForms with the following command:

```sh
$ bower install hriebl/tgForms
```

If you want to download a specific pre-compiled version of tgForms, just append the version number to the command, e.g.:

```sh
$ bower install hriebl/tgForms#0.1
```


## Compilation

Compiling tgForms is easy if you have [CoffeeScript](http://coffeescript.org) and [Cake](http://coffeescript.org/documentation/docs/cake.html) installed. In the tgForms directory, execute:

```sh
$ cake build
```

You may also minify the compiled JS file by running these commands:

```sh
$ wget "http://dl.google.com/closure-compiler/compiler-latest.zip"
$ unzip -nx "compiler-latest.zip"
$ cake minify
```


## Vocabulary

tgForms understands some [RDF Schema](http://www.w3.org/TR/rdf-schema) properties, namely rdfs:domain, rdfs:label, and rdfs:range, and interprets their subjects as form fields. Forms can be generated for classes that are used as objects of rdfs:domain. The library also comes with the following specific properties to refine forms:

### tgforms:hasInput

> Sets the input type for a property.

### tgforms:hasDefault

> Sets the default value for a property.

### tgforms:hasOption

> Sets a dropdown option for a property.

### tgforms:hasPriority

> Sets the priority for a property. Higher priorities appear first.

### tgforms:isRepeatable

> Makes a property repeatable.

<br> The following input types are available for the use with tgforms:hasInput:

### tgforms:button

> A button. May be manually scripted.

### tgforms:checkbox

> A checkbox. Useful for boolean properties.

### tgforms:dropdown

> A dropbox menu. Useful if there is a limited number of options.

### tgforms:text

> A text field. Useful for short texts.

### tgforms:textarea

> A text area. Useful to longer texts.


## Usage

tgForms is compatible with the RDF/Turtle from [schema.rdfs.org](http://schema.rdfs.org). If you like, take a look at [some CoffeScript code](https://github.com/hriebl/bolPerson/blob/master/src/main/webapp/bolPerson.coffee) that generates a form for the schema:BarOrPub class.

**TODO**: Add up-to-date information about public methods, for the moment take a look at [the source code](https://github.com/hriebl/tgForms/blob/944c179cc22bd261ba590c58e440c6c75e276c9e/tgForms.coffee#L236).
