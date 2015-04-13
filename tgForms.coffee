class tgForms

  ##### Variables #####

  # Object for the field templates, filled durgin the build process

  templates = {}

  # Regular expressions used to add icons to the field labels

  labelSearch = new RegExp("<span class=\"label\">(.*)<\/span>")
  resourceReplace = "<span class=\"label\">$1<\/span><span class=\"resource " +
      "glyphicon glyphicon-link icon-link\" aria-hidden=\"true\"></span>"
  repeatReplace = "<span class=\"label\">$1<\/span><span class=\"repeat " +
      "glyphicon glyphicon-plus icon-plus\" aria-hidden=\"true\"></span>"
  deleteReplace = "<span class=\"label\">$1<\/span><span class=\"delete " +
      "glyphicon glyphicon-minus icon-minus\" aria-hidden=\"true\"></span>"

  parser = N3.Parser()
  store = N3.Store()
  util = N3.Util


  ##### Private methods #####

  abbrevURI = (string) ->
    for prefix, uri of getPrefixes()
      string = string.replace(uri, prefix + ":")

    return string

  addToJSONLD = (jsonLD, domObject) ->
    if domObject.attr("type") is "checkbox"
      if domObject.prop("checked")
        newValue = true
      else
        return jsonLD

    if domObject.attr("type") is "text"
      if domObject.val()
        newValue = domObject.val()
      else
        return jsonLD

    if domObject.prop("tagName") is "SPAN"
      if domObject.text()
        newValue = domObject.text()
      else
        return jsonLD

    if domObject.prop("tagName") is "TEXTAREA"
      if domObject.val()
        newValue = domObject.val()
      else
        return jsonLD

    key = domObject.closest("div.form-group").attr("data-tgforms-name")

    if isResource(key)
      newValue = {"@id": newValue}

    oldValue = jsonLD[key]

    if oldValue instanceof Array
      jsonLD[key].push(newValue)
    else if oldValue
      jsonLD[key] = [oldValue, newValue]
    else
      jsonLD[key] = newValue

    return jsonLD

  expandPrefix = (string) ->
    return util.expandPrefixedName(string, getPrefixes())

  getClasses = (subject) ->
    rdfClasses = [subject]
    subClassOfTriples = store.find(subject, "rdfs:subClassOf", null)

    for subClassOfTriple in subClassOfTriples
      rdfClass = abbrevURI(subClassOfTriple.object)
      rdfClasses.push(rdfClass)

      for rdfClass in getClasses(rdfClass)
        if rdfClasses.indexOf(rdfClass) is -1
          rdfClasses.push(rdfClass)

    return rdfClasses

  getFieldHTML = (fieldObject) ->
    template = templates[fieldObject["tgforms:hasInput"]]
    fieldHTML = Mustache.render(template, fieldObject)

    if isResource(fieldObject["rdf:Property"])
      fieldHTML = fieldHTML.replace(labelSearch, resourceReplace)

    if fieldObject["tgforms:isRepeatable"]
      fieldHTML = fieldHTML.replace(labelSearch, repeatReplace)

    return fieldHTML

  getFieldObject = (fieldName) ->
    field = {}

    propTriples = store.find(fieldName, null, null)
    field["rdf:Property"] = abbrevURI(propTriples[0].subject)
    field["tgforms:hasOption"] = []

    for propTriple in propTriples
      key = propTriple.predicate
      key = abbrevURI(key)

      value = propTriple.object

      if util.isLiteral(value)
        value = util.getLiteralValue(value)

      value = abbrevURI(value)

      if key is "tgforms:hasOption"
        field["tgforms:hasOption"].push(value)
      else
        field[key] = value

    if not field["tgforms:hasInput"]
      field["tgforms:hasInput"] = "tgforms:text"

    field["tgforms:hasOption"] = field["tgforms:hasOption"].sort()
    field["tgforms:hasPriority"] = parseInt(field["tgforms:hasPriority"])

    if field["tgforms:isRepeatable"] isnt "false"
      field["tgforms:isRepeatable"] = true
    else
      field["tgforms:isRepeatable"] = false

    return field

  getFormTriples = (subject) ->
    formTriples = []
    rdfClasses = getClasses(subject)

    for rdfClass in rdfClasses
      triples = store.find(null, null, rdfClass)
      for triple in triples
        if triple.predicate is expandPrefix("rdfs:domain")
          formTriples.push(triple)
        else if triple.predicate is expandPrefix("rdf:first")

          # We expect a statement like
          # "rdfs:domain [ a owl:Class; owl:unionOf (bol:thing bol:person) ]"
          # and want to find its domain

          listStart = getListStart(triple.subject)

          # Replace blank node with RDF class

          listStart.object = expandPrefix(rdfClass)

          if listStart.predicate is expandPrefix("rdfs:domain")
            formTriples.push(listStart)

    return formTriples

  getList = (subject) ->
    list = []

    firstObject = store.find(subject, "rdf:first", null)[0].object
    restObject = store.find(subject, "rdf:rest", null)[0].object

    list.push(abbrevURI(firstObject))

    if abbrevURI(restObject) isnt "rdf:nil"
      for element in getList(restObject)
        list.push(abbrevURI(element))

    return list

  getListStart = (object) ->
    triple = store.find(null, null, object)

    if util.isBlank(triple[0].subject)
      return getListStart(triple[0].subject)
    else
      return triple[0]

  getPrefixes = ->
    return store._prefixes

  getUnionOf = (subject, predicate) ->
    mainObject = store.find(subject, predicate, null)[0].object
    unionOfObject = store.find(mainObject, "owl:unionOf", null)[0].object
    return unionOfObject

  isResource = (subject) ->
    rangeObject = store.find(subject, "rdfs:range", null)[0].object
    result = false

    if not abbrevURI(rangeObject).match(/^xsd:/)
      result = true

      if util.isBlank(rangeObject)
        for element in getList(getUnionOf(subject, "rdfs:range"))
          if element.match(/^xsd:/)
            result = result and false

    return result

  prefixCall = (prefix, uri) ->
    store.addPrefix(prefix, uri)

  repeatField = ->
    $this = $(this)

    fieldName = $this.closest("div.form-group").attr("data-tgforms-name")
    fieldHTML = getFieldHTML(getFieldObject(fieldName))
    fieldHTML = fieldHTML.replace(labelSearch, deleteReplace)

    $this.closest("div.form-group").after(fieldHTML)
    $("span.repeat").unbind("click").click(repeatField)

    $this.closest("div.form-group").next().find("span.delete").click(->
      $(this).closest("div.form-group").remove()
    )

    focusCall = -> $this.closest("div.form-group").next().find("input").focus()
    setTimeout(focusCall, 25)

  sortFields = (a, b) ->
    if a["tgforms:hasPriority"] > b["tgforms:hasPriority"]
      return -1
    else
      return 1


  ##### Public methods #####

  abbrevURI: (string) ->
    return abbrevURI(string)

  addTurtle: (turtle, addCall) ->
    tripleCall = (error, triple, prefixes) ->
      if triple
        store.addTriple(triple)
      else
        addCall()

    parser.parse(turtle, tripleCall, prefixCall)

  buildForm: (formName, selector) ->
    form = []
    formHTML = "<form role=\"form\" class=\"tgForms\">"

    for formTriple in getFormTriples(formName)
      form.push(getFieldObject(formTriple.subject))

    form = form.sort(sortFields)

    for fieldObject in form
      formHTML += getFieldHTML(fieldObject)

    formHTML += "</form>"
    $(selector).html(formHTML)

    $("span.repeat").unbind("click").click(repeatField)

    $("form.tgForms").on("click", "ul.dropdown-menu li", ->
      $(this).closest("div.form-group").find("span.value").text($(this).text())
    )

  fillForm: (subject, selector) ->
    triples = store.find(subject, null, null)

    for triple in triples
      predicate = triple.predicate
      predicate = abbrevURI(predicate)
      predicate = predicate.replace(":", "\\:")

      object = triple.object

      if util.isLiteral(object)
        object = util.getLiteralValue(object)

      object = abbrevURI(object)

      $this = $(selector + " div." + predicate).last()

      if $this.find("input").attr("type") is "checkbox"
        if object is "true"
          $this.find("input").prop("checked", true)

      if $this.find("input").attr("type") is "text"
        if $this.find("input").val()
          field = $this.closest("div.form-group").clone()
          field.children().find("input").val(object)
          $this.closest("div.form-group").after(field)
        else
          $this.find("input").val(object)

      if $this.find("span.value")
        if $this.find("span.value").text()
          field = $this.closest("div.form-group").clone()
          field.children().find("span.value").text(object)
          $this.closest("div.form-group").after(field)
        else
          $this.find("span.value").text(object)

      if $this.find("textarea")
        if $this.find("textarea").val()
          field = $this.closest("div.form-group").clone()
          field.children().find("textarea").val(object)
          $this.closest("div.form-group").after(field)
        else
          $this.find("textarea").val(object)

    $("span.repeat").unbind("click").click(repeatField)

  getFieldHTML: (fieldObject) ->
    return getFieldHTML(fieldObject)

  getFieldObject: (fieldName) ->
    return getFieldObject(fieldName)

  getFormField: (fieldName) ->
    # DEPRECATED as of 04/09/15: Please use getFieldObject instead
    console.log("getFormField is DEPRECATED: Please use getFieldObject instead")
    return getFieldObject(fieldName)

  getInput: (subject, type, selector) ->
    jsonLD = {
      "@context": getPrefixes(),
      "@id": subject,
      "@type": type
    }

    $(selector + " input").each ->
      $this = $(this)
      jsonLD = addToJSONLD(jsonLD, $this)

    $(selector + " span.value").each ->
      $this = $(this)
      jsonLD = addToJSONLD(jsonLD, $this)

    $(selector + " textarea").each ->
      $this = $(this)
      jsonLD = addToJSONLD(jsonLD, $this)

    return jsonLD

  getPrefixes: ->
    return getPrefixes()

  getStore: ->
    return store

  getType: (subject) ->
    type = store.find(subject, "rdf:type", null)[0].object
    type = util.getLiteralValue(type) if util.isLiteral(type)
    return abbrevURI(type)

  renderField: (fieldObject) ->
    # DEPRECATED as of 04/09/15: Please use makeField instead
    console.log("renderField is DEPRECATED: Please use getFieldHTML instead")
    return getFieldHTML(fieldObject)
