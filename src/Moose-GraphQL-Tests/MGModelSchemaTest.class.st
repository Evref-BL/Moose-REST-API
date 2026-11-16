"
I test the ""model mode"" schema built by MGModelSchemaBuilder on the MGTestModel fixture (Class1 {m1, m2, a1}, Class2 {m3}): the GraphQL object types are the metamodel concepts of the model (Attribute, Class, Method) instead of the generic Entity/MetaClass/Model/Property/Relation types.

Queries are executed against the model schema with an MGRegistry forModel: context; ids are therefore computed with that registry (see #modelIdOf:).
I also cover the hidden helper types of polymorphic relations (TWithComments, on a separate model with comments), MGEmptyModelError and the type naming helpers.
"
Class {
	#name : 'MGModelSchemaTest',
	#superclass : 'MGTestCase',
	#instVars : [
		'modelSchema'
	],
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'helpers' }
MGModelSchemaTest >> annotationModelWithValues: aCollection [
	"A separate model (never installed, name starting with MGTest so that tearDown cleans it anyway) holding a class named Foo and one AnnotationInstanceAttribute per element of aCollection, whose Object-typed value is that element.
	A one-argument block is evaluated with the model to answer the value (e.g. an entity of the model).
	The Foo class makes Object satisfied by two concrete classes: when value stays a relation, it is typed with the helper type Object"

	| annotationModel attributes |
	annotationModel := FamixStModel new name: 'MGTestAnnotations'.
	annotationModel add: (FamixStClass named: 'Foo').
	attributes := aCollection collect: [ :each |
		              FamixStAnnotationInstanceAttribute new ].
	annotationModel addAll: attributes.
	aCollection with: attributes do: [ :each :attribute |
			attribute value: (each isBlock
					 ifTrue: [ each value: annotationModel ]
					 ifFalse: [ each ]) ].
	^ annotationModel
]

{ #category : 'helpers' }
MGModelSchemaTest >> assertSweepOf: aSchema model: aMooseModel [
	"Query every entity of every root concept selecting all its scalar fields (built from introspection); assert no exception escapes, no GraphQL error is reported and every list has the expected size.
	Only the concept list fields (whose named type is an OBJECT) are swept. rootEntities (typed with the MooseEntity interface) is checked separately: it answers every entity without container that has a concept.
	Some properties raise internally (e.g. numberOfAbstractMethods on FamixTest1Class): they must resolve to null, not to an error"

	| introspected rootFields conceptNames query response data roots |
	introspected := self introspectedSchemaOf: aSchema model: aMooseModel.
	rootFields := ((introspected at: 'queryType') at: 'fields') select: [ :f |
		              | kinds |
		              kinds := self kindsOf: (f at: 'type').
		              (kinds includes: 'LIST') and: [ (kinds at: kinds size - 1) = 'OBJECT' ] ].
	self assert: rootFields notEmpty.
	conceptNames := (((introspected at: 'types') select: [ :t | (t at: 'kind') = 'OBJECT' ]) collect: [ :t | t at: 'name' ]) asSet.
	query := String streamContents: [ :s |
		         s nextPutAll: '{ '.
		         rootFields do: [ :f |
			         | typeName scalars |
			         typeName := (self kindsOf: (f at: 'type')) last.
			         scalars := (self fieldsOfType: typeName in: introspected) values select: [ :field |
				                    (self kindsOf: (field at: 'type')) includes: 'SCALAR' ].
			         s nextPutAll: (f at: 'name'); nextPutAll: '(take: 1000) { '.
			         scalars do: [ :field | s nextPutAll: (field at: 'name') ] separatedBy: [ s space ].
			         s nextPutAll: ' } ' ].
		         s nextPutAll: '}' ].
	self shouldnt: [ response := self query: query variables: nil on: aSchema model: aMooseModel ] raise: Error.
	data := self dataFrom: response.
	rootFields do: [ :f |
		| typeName |
		typeName := (self kindsOf: (f at: 'type')) last.
		self
			assert: (data at: (f at: 'name')) size
			equals: (aMooseModel entities count: [ :e |
				 ([ e metadescription name asString ] on: Error do: [ :err | err return: nil ]) = typeName ]).
		(data at: (f at: 'name')) do: [ :entity |
			self assert: (entity at: 'type') equals: typeName.
			self assert: (entity at: 'id') isString ] ].
	"rootEntities: the entities without container that have a concept, typed with their concrete concept"
	roots := (self dataFrom: (self query: '{ rootEntities(take: 1000) { __typename id type } }' variables: nil on: aSchema model: aMooseModel)) at: 'rootEntities'.
	self assert: roots size equals: (aMooseModel entities count: [ :e |
			 ([ e containers isEmpty ] on: Error do: [ :err | err return: false ]) and: [
				 conceptNames includes: ([ e metadescription name asString ] on: Error do: [ :err | err return: nil ]) ] ]).
	roots do: [ :entity |
		self assert: (conceptNames includes: (entity at: '__typename')).
		self assert: (entity at: 'id') isString ].
	^ data
]

{ #category : 'helpers' }
MGModelSchemaTest >> commentedModel [
	"A separate model (never installed, name starting with MGTest so that tearDown cleans it anyway) where comments are attached to a class and to a method.
	Comment.commentedEntity is declared as FamixTWithComments, to which both Class and Method conform: it is typed with the hidden helper type TWithComments"

	| commented class method classComment methodComment |
	commented := FamixTest1Model new name: 'MGTestCommented'.
	class := FamixTest1Class named: 'CommentedClass'.
	method := FamixTest1Method named: 'commentedMethod'.
	class addMethod: method.
	classComment := FamixTest1Comment new.
	classComment commentedEntity: class.
	methodComment := FamixTest1Comment new.
	methodComment commentedEntity: method.
	commented addAll: {
			class.
			method.
			classComment.
			methodComment }.
	^ commented
]

{ #category : 'helpers' }
MGModelSchemaTest >> conceptObjectTypesOf: anIntrospectedSchema [
	"Object types of the schema, excluding Query and the introspection types"

	^ (anIntrospectedSchema at: 'types') select: [ :t |
			  (t at: 'kind') = 'OBJECT' and: [
					  ((t at: 'name') beginsWith: '__') not and: [
						  (t at: 'name') ~= 'Query' ] ] ]
]

{ #category : 'helpers' }
MGModelSchemaTest >> dataFrom: aResponse [
	"Assert aResponse has no GraphQL error and answer its 'data' entry"

	self assert: (aResponse includesKey: 'errors') not description: [
			'Unexpected errors: '
			, (aResponse at: 'errors' ifAbsent: [ #(  ) ]) printString ].
	^ aResponse at: 'data'
]

{ #category : 'helpers' }
MGModelSchemaTest >> fieldsOfType: aTypeName in: anIntrospectedSchema [
	"Dictionary field name -> introspected field of the type aTypeName"

	| type byName |
	type := (anIntrospectedSchema at: 'types') detect: [ :t |
		        (t at: 'name') = aTypeName ].
	byName := Dictionary new.
	(type at: 'fields') do: [ :f | byName at: (f at: 'name') put: f ].
	^ byName
]

{ #category : 'helpers' }
MGModelSchemaTest >> introspectedSchema [
	"__schema of the fixture model schema"

	^ self introspectedSchemaOf: self modelSchema model: model
]

{ #category : 'helpers' }
MGModelSchemaTest >> introspectedSchemaOf: aSchema model: aMooseModel [
	"__schema of aSchema: query type fields (with args) and all types (with description and fields)"

	| typeRef |
	typeRef := 'type { kind name ofType { kind name ofType { kind name ofType { kind name } } } }'.
	^ (self dataFrom: (self
			    query:
				    '{ __schema { queryType { name fields { name args { name '
				    , typeRef , ' } ' , typeRef
				    ,
				    ' } } types { kind name description fields { name description '
				    , typeRef , ' } } } }'
			    variables: nil
			    on: aSchema
			    model: aMooseModel)) at: '__schema'
]

{ #category : 'helpers' }
MGModelSchemaTest >> kindsOf: aTypeDictionary [
	"Answer the chain of kinds of an introspected type reference, ending with the named type, e.g. #('NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Method')"

	| result current |
	result := OrderedCollection new.
	current := aTypeDictionary.
	[ current notNil ] whileTrue: [
			result add: (current at: 'kind').
			(current at: 'name') ifNotNil: [ :n | result add: n ].
			current := current at: 'ofType' ifAbsent: [ nil ] ].
	^ result asArray
]

{ #category : 'helpers' }
MGModelSchemaTest >> modelDataOf: aString [

	^ self modelDataOf: aString variables: nil
]

{ #category : 'helpers' }
MGModelSchemaTest >> modelDataOf: aString variables: aDictionaryOrNil [
	"Execute aString in model mode, assert it produced no GraphQL error and answer its 'data' entry"

	^ self dataFrom:
		  (self modelQuery: aString variables: aDictionaryOrNil)
]

{ #category : 'helpers' }
MGModelSchemaTest >> modelIdOf: anEntity [
	"Opaque id of anEntity in model mode (the model-mode registry only knows the served model)"

	^ (MGRegistry forModel: model) idOfEntity: anEntity
]

{ #category : 'helpers' }
MGModelSchemaTest >> modelQuery: aString variables: aDictionaryOrNil [
	"Execute aString against the model schema with a fresh model-mode registry; answer the response dictionary ('data' / 'errors')"

	^ self
		  query: aString
		  variables: aDictionaryOrNil
		  on: self modelSchema
		  model: model
]

{ #category : 'helpers' }
MGModelSchemaTest >> modelSchema [
	"The model-mode schema of the fixture model, built once per test"

	^ modelSchema ifNil: [
		  modelSchema := MGModelSchemaBuilder buildFor: model ]
]

{ #category : 'helpers' }
MGModelSchemaTest >> query: aString variables: aDictionaryOrNil on: aSchema model: aMooseModel [
	"Execute aString against aSchema in model mode on aMooseModel; answer the response dictionary"

	^ aSchema
		  execute: aString
		  operationName: nil
		  variables: aDictionaryOrNil
		  context: (MGRegistry forModel: aMooseModel)
]

{ #category : 'tests' }
MGModelSchemaTest >> testByIdAndRelations [
	"class(id:) on Class1 answers it, with m1 and m2 through methods and a1 through attributes; method(id:) navigates back with parentType"

	| data class methods |
	data := self
		        modelDataOf:
		        'query($c: ID!, $m: ID!, $a: ID!) { class(id: $c) { id name type methods { id name parentType { name } } attributes { name parentType { name } } } method(id: $m) { name parentType { id name } } attribute(id: $a) { name parentType { name } } }'
		        variables: (Dictionary new
				         at: 'c' put: (self modelIdOf: class1);
				         at: 'm' put: (self modelIdOf: m3);
				         at: 'a' put: (self modelIdOf: a1);
				         yourself).
	class := data at: 'class'.
	self assert: (class at: 'id') equals: (self modelIdOf: class1).
	self assert: (class at: 'name') equals: 'Class1'.
	self assert: (class at: 'type') equals: 'Class'.
	methods := class at: 'methods'.
	self
		assert: (methods collect: [ :m | m at: 'name' ]) asSet
		equals: #( 'm1' 'm2' ) asSet.
	self assert: (methods collect: [ :m | m at: 'id' ]) asSet equals: {
			(self modelIdOf: m1).
			(self modelIdOf: m2) } asSet.
	self assert: (methods allSatisfy: [ :m |
			 ((m at: 'parentType') at: 'name') = 'Class1' ]).
	self
		assert:
		((class at: 'attributes') collect: [ :a | a at: 'name' ]) asArray
		equals: #( 'a1' ).
	self
		assert: (((data at: 'method') at: 'parentType') at: 'id')
		equals: (self modelIdOf: class2).
	self
		assert: (((data at: 'attribute') at: 'parentType') at: 'name')
		equals: 'Class1'
]

{ #category : 'tests' }
MGModelSchemaTest >> testByIdOfAnotherConceptOrUnknownAnswersNull [
	"A by-id field answers null, without GraphQL error, for the id of an entity of another concept, an unknown id or a malformed id"

	| data |
	data := self
		        modelDataOf:
		        'query($m: ID!, $c: ID!) { classAsMethod: class(id: $m) { id } methodAsClass: method(id: $c) { id } attributeAsClass: attribute(id: $c) { id } unknown: class(id: "999999:1") { id } malformed: method(id: "zz") { id } empty: attribute(id: "") { id } }'
		        variables: (Dictionary new
				         at: 'm' put: (self modelIdOf: m1);
				         at: 'c' put: (self modelIdOf: class1);
				         yourself).
	#( 'classAsMethod' 'methodAsClass' 'attributeAsClass'
	   'unknown' 'malformed' 'empty' ) do: [ :key |
			self assert: (data includesKey: key).
			self
				assert: (data at: key) isNil
				description: key , ' should be null' ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testCommentedModelInterfaces [
	"The supertype TWithComments of Class and Method is an INTERFACE implementing MooseEntity first, with the generic fields; MooseEntity is implemented by the object types only; rootEntities of the commented model is CommentedClass"

	| commented schema data |
	commented := self commentedModel.
	schema := MGModelSchemaBuilder buildFor: commented.
	data := self dataFrom: (self
		query: '{ interface: __type(name: "TWithComments") { kind interfaces { name } possibleTypes { name } fields { name } } entity: __type(name: "MooseEntity") { possibleTypes { name } } rootEntities { __typename name } }'
		variables: nil on: schema model: commented).
	self assert: ((data at: 'interface') at: 'kind') equals: 'INTERFACE'.
	self assert: (((data at: 'interface') at: 'interfaces') collect: [ :i | i at: 'name' ]) first equals: 'MooseEntity'.
	self assert: (((data at: 'interface') at: 'possibleTypes') collect: [ :t | t at: 'name' ]) asSet equals: #( 'Class' 'Method' ) asSet.
	self assert: ((((data at: 'interface') at: 'fields') collect: [ :f | f at: 'name' ]) includesAll: MGModelSchemaBuilder genericFieldNames).
	self assert: (((data at: 'entity') at: 'possibleTypes') collect: [ :t | t at: 'name' ]) asSet equals: #( 'Class' 'Comment' 'Method' ) asSet.
	self assert: ((data at: 'rootEntities') collect: [ :e | e at: 'name' ]) asArray equals: #( 'CommentedClass' ).
	self assert: ((data at: 'rootEntities') collect: [ :e | e at: '__typename' ]) asArray equals: #( 'Class' )
]

{ #category : 'tests' }
MGModelSchemaTest >> testConcepts [
	"MGConcept describes the generated types: object concepts (concrete classes having instances) and interface concepts (their FM3 supertypes); both carry root field names"

	| builder objects interfaces withComments |
	builder := MGModelSchemaBuilder on: self commentedModel.
	builder build.
	objects := builder concepts select: [ :c | c isRoot ].
	interfaces := builder concepts select: [ :c | c isInterface ].
	self assert: (objects collect: [ :c | c typeName ]) asSet equals: #( 'Class' 'Comment' 'Method' ) asSet.
	self assert: (builder rootConcepts collect: [ :c | c typeName ]) asSet equals: (objects collect: [ :c | c typeName ]) asSet.
	self assert: (objects allSatisfy: [ :c | c isObject and: [ c kind = #object and: [ c isHelper not ] ] ]).
	self assert: builder concepts size equals: objects size + interfaces size.
	self assert: (builder sortedInterfaceConcepts collect: [ :c | c typeName ]) asSet equals: (interfaces collect: [ :c | c typeName ]) asSet.
	(objects detect: [ :c | c typeName = 'Class' ]) in: [ :class |
		self assert: class listFieldName equals: 'classes'.
		self assert: class byIdFieldName equals: 'class'.
		self deny: class isHelper.
		self assert: class shortName equals: 'Class'.
		self assert: class fullName equals: 'Famix-Test1-Entities.Class' ].
	interfaces do: [ :each |
		self assert: each kind equals: #interface.
		self deny: each isRoot.
		self assert: each isHelper.
		self assert: each listFieldName notNil.
		self assert: each byIdFieldName notNil ].
	withComments := interfaces detect: [ :c | c typeName = 'TWithComments' ].
	self assert: (withComments conformingClasses collect: [ :c | c name asString ]) asSet equals: #( 'Class' 'Method' ) asSet.
	self assert: (withComments description includesSubstring: 'interface').
	self assert: (withComments description includesSubstring: 'Class, Method')
]

{ #category : 'tests' }
MGModelSchemaTest >> testEmptyModelSignalsError [
	"A model without any entity to expose cannot be served in model mode"

	| empty error |
	empty := FamixTest1Model new name: 'MGTestEmpty'.
	error := nil.
	[ MGModelSchemaBuilder buildFor: empty ]
		on: MGEmptyModelError
		do: [ :e | error := e ].
	self assert: error notNil.
	self assert: error modelName equals: 'MGTestEmpty'.
	self
		assert: error messageText
		equals: 'Model MGTestEmpty has no entity to expose'.
	self
		should: [ MGModelSchemaBuilder buildFor: empty ]
		raise: MGEmptyModelError.
	self
		assert: (MGEmptyModelError new
				 modelName: 'X';
				 messageText)
		equals: 'Model X has no entity to expose'
]

{ #category : 'tests' }
MGModelSchemaTest >> testFASTTestModelSchema [
	"A FAST model (FASTTestModel: a class holding a method statement) gets object types Class and Method, interfaces for the FAST traits, and the generic containment fields work"

	| env fast class method schema introspected kinds data |
	env := self class environment.
	(env includesKey: #FASTTestModel) ifFalse: [ ^ self skip: 'FAST-Core-Test-Model is not loaded' ].
	fast := (env at: #FASTTestModel) new name: 'MGTestFAST'.
	class := (env at: #FASTTestClass) new.
	method := (env at: #FASTTestMethod) new.
	(class respondsTo: #name:) ifTrue: [ class name: 'FastClass' ].
	(method respondsTo: #name:) ifTrue: [ method name: 'fastMethod' ].
	class addStatement: method.
	fast addAll: { class. method }.
	schema := MGModelSchemaBuilder buildFor: fast.
	introspected := self introspectedSchemaOf: schema model: fast.
	self
		assert: ((self conceptObjectTypesOf: introspected) collect: [ :t | t at: 'name' ]) asSet
		equals: #( 'Class' 'Method' ) asSet.
	kinds := Dictionary new.
	(introspected at: 'types') do: [ :t | kinds at: (t at: 'name') put: (t at: 'kind') ].
	#( 'TStatement' 'TStatementBlock' 'TNamedBehaviouralEntity' 'Entity' 'MooseEntity' ) do: [ :name |
		self assert: (kinds at: name ifAbsent: [ nil ]) equals: 'INTERFACE' ].
	data := self dataFrom: (self
		query: '{ rootEntities { __typename children { __typename } } }'
		variables: nil on: schema model: fast).
	self assert: ((data at: 'rootEntities') collect: [ :e | e at: '__typename' ]) asArray equals: #( 'Class' ).
	self assert: (((data at: 'rootEntities') first at: 'children') collect: [ :e | e at: '__typename' ]) asArray equals: #( 'Method' )
]

{ #category : 'tests' }
MGModelSchemaTest >> testFieldNameHelper [
	"A property named id is renamed id_ (id is the opaque identity field); a name already used answers nil (the property is skipped)"

	| builder used |
	builder := MGModelSchemaBuilder on: model.
	used := Set withAll: #( 'id' 'name' 'type' ).
	self
		assert: (builder
				 fieldNameFor: (FM3Property new
						  name: #id;
						  yourself)
				 among: used)
		equals: 'id_'.
	self assert: (used includes: 'id_').
	self assert: (builder
			 fieldNameFor: (FM3Property new
					  name: #name;
					  yourself)
			 among: used) isNil.
	self
		assert: (builder
				 fieldNameFor: (FM3Property new
						  name: #numberOfMethods;
						  yourself)
				 among: used)
		equals: 'numberOfMethods'
]

{ #category : 'tests' }
MGModelSchemaTest >> testFragmentsAndTypenameOnInterfaces [
	"Inline fragments on concrete types select fields inside an interface list; a fragment on an interface applies inside an object field; __typename is always the concrete type"

	| data entities class1 |
	data := self dataFrom: (self
		query: '{ namedEntities { __typename id ... on Class { name methods { name } } ... on Method { name } } classes { name methods { __typename ... on TNamedEntity { name } ... on TMethod { id } } } }'
		variables: nil on: self modelSchema model: model).
	entities := data at: 'namedEntities'.
	self assert: entities size equals: 6.
	self assert: (entities allSatisfy: [ :e | e includesKey: 'id' ]).
	(entities select: [ :e | (e at: '__typename') = 'Class' ]) do: [ :e | self assert: (e includesKey: 'methods') ].
	self
		assert: ((entities select: [ :e | (e at: '__typename') = 'Class' ]) collect: [ :e | e at: 'name' ]) asSet
		equals: #( 'Class1' 'Class2' ) asSet.
	self
		assert: ((entities select: [ :e | (e at: '__typename') = 'Method' ]) collect: [ :e | e at: 'name' ]) asSet
		equals: #( 'm1' 'm2' 'm3' ) asSet.
	(entities select: [ :e | (e at: '__typename') = 'Attribute' ]) do: [ :e |
		self deny: (e includesKey: 'name').
		self deny: (e includesKey: 'methods') ].
	class1 := (data at: 'classes') detect: [ :c | (c at: 'name') = 'Class1' ].
	self assert: ((class1 at: 'methods') collect: [ :m | m at: 'name' ]) asSet equals: #( 'm1' 'm2' ) asSet.
	(class1 at: 'methods') do: [ :m |
		self assert: (m at: '__typename') equals: 'Method'.
		self assert: (m includesKey: 'id') ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testGenericContainmentFields [
	"Generic containment fields reached through the concept root fields: Class1 contains a1, m1 and m2 and has no container; m1 is contained by Class1"

	| data c1 meth |
	data := self dataFrom: (self
			         query: '{ classes { name types childrenCount children { __typename name } firstChild: children(take: 1) { name } container { name } containers { name } ancestors { name } } methods { name type types container { __typename name } containers { __typename name } ancestors { name } firstAncestor: ancestors(take: 1) { name } children { name } childrenCount } }'
			         variables: nil on: self modelSchema model: model).
	c1 := (data at: 'classes') detect: [ :c | (c at: 'name') = 'Class1' ].
	self assert: (c1 at: 'childrenCount') equals: 3.
	self assert: ((c1 at: 'children') collect: [ :c | c at: 'name' ]) asSet equals: #( 'a1' 'm1' 'm2' ) asSet.
	"children are typed with their concrete concept"
	self assert: ((c1 at: 'children') collect: [ :c | c at: '__typename' ]) asSet equals: #( 'Attribute' 'Method' ) asSet.
	self assert: (c1 at: 'firstChild') size equals: 1.
	self assert: (c1 at: 'container') isNil.
	self assert: (c1 at: 'containers') isEmpty.
	self assert: (c1 at: 'ancestors') isEmpty.
	self assert: (c1 at: 'types') first equals: 'Class'.
	meth := (data at: 'methods') detect: [ :m | (m at: 'name') = 'm1' ].
	self assert: (meth at: 'type') equals: 'Method'.
	self assert: (meth at: 'types') first equals: 'Method'.
	self assert: ((meth at: 'container') at: '__typename') equals: 'Class'.
	self assert: ((meth at: 'container') at: 'name') equals: 'Class1'.
	self assert: ((meth at: 'containers') collect: [ :c | c at: 'name' ]) asArray equals: #( 'Class1' ).
	self assert: ((meth at: 'containers') collect: [ :c | c at: '__typename' ]) asArray equals: #( 'Class' ).
	self assert: ((meth at: 'ancestors') collect: [ :c | c at: 'name' ]) asArray equals: #( 'Class1' ).
	self assert: (meth at: 'firstAncestor') size equals: 1.
	self assert: (meth at: 'children') isEmpty.
	self assert: (meth at: 'childrenCount') equals: 0
]

{ #category : 'tests' }
MGModelSchemaTest >> testGenericFieldNameClashRenamed [
	"FM3 properties named like a generic field get a trailing underscore; a name property is dropped (the generic name field already answers it). In a schema, the Tag concept (FM3 properties id and children) exposes id_ and children_ next to the generic fields"

	| builder used nameProperty tagModel tagFields |
	builder := MGModelSchemaBuilder on: model.
	used := MGModelSchemaBuilder genericFieldNames asSet.
	{
		('id' -> 'id_').
		('type' -> 'type_').
		('types' -> 'types_').
		('container' -> 'container_').
		('containers' -> 'containers_').
		('children' -> 'children_').
		('childrenCount' -> 'childrenCount_').
		('ancestors' -> 'ancestors_') } do: [ :pair |
		self assert: (builder fieldNameFor: (FM3Property new name: pair key; yourself) among: used) equals: pair value ].
	"a second property with the same name is dropped"
	self assert: (builder fieldNameFor: (FM3Property new name: 'type'; yourself) among: used) isNil.
	nameProperty := FamixTest1Method new metadescription allProperties detect: [ :p | p name = #name ].
	self assert: (builder fieldNameFor: nameProperty among: used) isNil.
	self assert: (MGModelSchemaBuilder renamedGenericFieldNames includes: 'name') not.
	tagModel := FamixTest1Model new name: 'MGTestTagged'.
	tagModel add: (FamixTag new name: 'aTag'; yourself).
	tagFields := self fieldsOfType: 'Tag' in: (self introspectedSchemaOf: (MGModelSchemaBuilder buildFor: tagModel) model: tagModel).
	self assert: (tagFields keys includesAll: MGModelSchemaBuilder genericFieldNames).
	self assert: (tagFields includesKey: 'id_').
	self assert: (tagFields includesKey: 'children_')
]

{ #category : 'tests' }
MGModelSchemaTest >> testIPrefixForConcreteSupertype [
	"FamixTest3ParametricClass is a subclass of FamixTest3Class: with instances of both, Class is an OBJECT answering exactly the Class instances, and its FM3 type also becomes the interface IClass, implemented by Class and ParametricClass"

	| test3 schema data objectInterfaces |
	test3 := FamixTest3Model new name: 'MGTestIPrefix'.
	test3 addAll: { FamixTest3Class named: 'C'. FamixTest3ParametricClass named: 'P' }.
	schema := MGModelSchemaBuilder buildFor: test3.
	data := self dataFrom: (self
		query: '{ object: __type(name: "Class") { kind interfaces { name } } interface: __type(name: "IClass") { kind interfaces { name } possibleTypes { name } } sub: __type(name: "ParametricClass") { kind interfaces { name } } classes { __typename name } }'
		variables: nil on: schema model: test3).
	objectInterfaces := ((data at: 'object') at: 'interfaces') collect: [ :i | i at: 'name' ].
	self assert: ((data at: 'object') at: 'kind') equals: 'OBJECT'.
	self assert: objectInterfaces first equals: 'MooseEntity'.
	self assert: (objectInterfaces includes: 'IClass').
	self assert: ((data at: 'interface') at: 'kind') equals: 'INTERFACE'.
	self deny: ((((data at: 'interface') at: 'interfaces') collect: [ :i | i at: 'name' ]) includes: 'IClass').
	self
		assert: (((data at: 'interface') at: 'possibleTypes') collect: [ :t | t at: 'name' ]) asSet
		equals: #( 'Class' 'ParametricClass' ) asSet.
	self assert: ((data at: 'sub') at: 'kind') equals: 'OBJECT'.
	self assert: ((((data at: 'sub') at: 'interfaces') collect: [ :i | i at: 'name' ]) includes: 'IClass').
	self assert: ((data at: 'classes') collect: [ :c | c at: 'name' ]) asArray equals: #( 'C' ).
	self assert: ((data at: 'classes') collect: [ :c | c at: '__typename' ]) asArray equals: #( 'Class' )
]

{ #category : 'tests' }
MGModelSchemaTest >> testIdentityFieldsAndDescriptions [
	"Every concept type has id: ID!, name: String, type: String, a type description and a description on every field (Query fields included)"

	| schema |
	schema := self introspectedSchema.
	(self conceptObjectTypesOf: schema)
	, ((schema at: 'types') select: [ :t | (t at: 'name') = 'Query' ])
		do: [ :t |
				| byName |
				self assert: (t at: 'description') notEmpty.
				byName := self fieldsOfType: (t at: 'name') in: schema.
				byName valuesDo: [ :f |
						self
							assert: ((f at: 'description') ifNil: [ '' ]) notEmpty
							description:
							(t at: 'name') , '.' , (f at: 'name') , ' has no description' ] ].
	(self conceptObjectTypesOf: schema) do: [ :t |
			| byName |
			self assert:
				((t at: 'description') includesSubstring: 'Moose concept').
			byName := self fieldsOfType: (t at: 'name') in: schema.
			self
				assert: (self kindsOf: ((byName at: 'id') at: 'type'))
				equals: #( 'NON_NULL' 'SCALAR' 'ID' ).
			self
				assert: (self kindsOf: ((byName at: 'name') at: 'type'))
				equals: #( 'SCALAR' 'String' ).
			self
				assert: (self kindsOf: ((byName at: 'type') at: 'type'))
				equals: #( 'SCALAR' 'String' ) ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testInterfaceFieldDroppedWhenIncompatible [
	"computeFields keeps an interface field only when every implementer (object or sub-interface) has a compatible field, up to a fixpoint.
	Hand-built concepts (see MGFixedFieldsSchemaBuilder): objects a and b; interface sub implemented by a and b; interface superInterface implemented by a and sub only, processed first (sorted by FM3 fullName: Attribute before Comment).
	x: b has a Number scalar instead of a String one; r: b is single-valued instead of multivalued. Both are dropped from sub on the first pass, then from superInterface on the second pass (sub no longer provides them). y is compatible everywhere and stays; object fields are untouched"

	| fieldsOf a b sub superInterface builder |
	fieldsOf := [ :xScalar :rMultivalued |
		Dictionary new
			at: 'x' put: (MGConceptField scalarNamed: 'x' property: nil scalarName: xScalar multivalued: false);
			at: 'y' put: (MGConceptField scalarNamed: 'y' property: nil scalarName: 'String' multivalued: false);
			at: 'r' put: (MGConceptField relationNamed: 'r' property: nil target: nil multivalued: rMultivalued);
			yourself ].
	a := MGConcept objectType: FamixTest1Class metadescription conformingClasses: #(  ).
	b := MGConcept objectType: FamixTest1Method metadescription conformingClasses: #(  ).
	sub := MGConcept interfaceType: FamixTest1Comment metadescription conformingClasses: #(  ).
	superInterface := MGConcept interfaceType: FamixTest1Attribute metadescription conformingClasses: #(  ).
	a fields: (fieldsOf value: 'String' value: true).
	b fields: (fieldsOf value: 'Number' value: false).
	sub fields: (fieldsOf value: 'String' value: true).
	superInterface fields: (fieldsOf value: 'String' value: true).
	a interfaces: { sub. superInterface }.
	b interfaces: { sub }.
	sub interfaces: { superInterface }.
	superInterface interfaces: #(  ).
	builder := MGFixedFieldsSchemaBuilder new objects: { a. b } interfaces: { sub. superInterface }.
	self assert: builder sortedInterfaceConcepts asArray equals: { superInterface. sub }.
	self assert: (builder implementersOf: superInterface) asSet equals: { a. sub } asSet.
	self assert: (builder implementersOf: sub) asSet equals: { a. b } asSet.
	builder computeFields.
	self assert: sub fields keys asSet equals: #( 'y' ) asSet.
	self assert: superInterface fields keys asSet equals: #( 'y' ) asSet.
	self assert: a fields keys asSet equals: #( 'r' 'x' 'y' ) asSet.
	self assert: b fields keys asSet equals: #( 'r' 'x' 'y' ) asSet
]

{ #category : 'tests' }
MGModelSchemaTest >> testInterfaceFieldsAreSharedByImplementers [
	"For each interface, every possible type has each field of the interface, with the same wrappers (list, non null) and the same named type or a type implementing it (covariant relation)"

	| types byName conforms interfaces |
	types := ((self dataFrom: (self
		query: '{ __schema { types { kind name interfaces { name } possibleTypes { name } fields { name type { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } } }'
		variables: nil on: self modelSchema model: model)) at: '__schema') at: 'types'.
	byName := Dictionary new.
	types do: [ :t | byName at: (t at: 'name') put: t ].
	conforms := [ :implName :ifaceName |
		implName = ifaceName or: [
			(((byName at: implName) at: 'interfaces') ifNil: [ #(  ) ]) anySatisfy: [ :i | (i at: 'name') = ifaceName ] ] ].
	interfaces := types select: [ :t | (t at: 'kind') = 'INTERFACE' ].
	self assert: interfaces size > 2.
	interfaces do: [ :iface |
		self assert: (iface at: 'possibleTypes') notEmpty.
		(iface at: 'possibleTypes') do: [ :possible |
			| implFields |
			implFields := Dictionary new.
			((byName at: (possible at: 'name')) at: 'fields') do: [ :f | implFields at: (f at: 'name') put: f ].
			(iface at: 'fields') do: [ :field |
				| implField ifaceKinds implKinds |
				implField := implFields at: (field at: 'name') ifAbsent: [ nil ].
				self assert: implField notNil description: [ (possible at: 'name') , ' misses ' , (iface at: 'name') , '.' , (field at: 'name') ].
				ifaceKinds := self kindsOf: (field at: 'type').
				implKinds := self kindsOf: (implField at: 'type').
				self assert: (implKinds first: implKinds size - 2) equals: (ifaceKinds first: ifaceKinds size - 2).
				self
					assert: (conforms value: implKinds last value: ifaceKinds last)
					description: [ (possible at: 'name') , '.' , (field at: 'name') , ' is not compatible with ' , (iface at: 'name') ] ] ] ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testInterfaceForPolymorphicRelation [
	"Comment.commentedEntity is declared as FamixTWithComments, satisfied by both Class and Method in the commented model:
	it is typed with the interface TWithComments, which has the identity fields and its own root fields,
	and its values report their concrete concept through __typename and type"

	| commented builder schema introspected queryFields queryFieldNames commentFields interface concept data |
	commented := self commentedModel.
	builder := MGModelSchemaBuilder on: commented.
	schema := builder build.
	introspected := self introspectedSchemaOf: schema model: commented.
	queryFields := (introspected at: 'queryType') at: 'fields'.
	queryFieldNames := (queryFields collect: [ :f | f at: 'name' ]) asSet.
	self assert: (queryFieldNames includesAll: #( 'rootEntities' 'classes' 'class' 'comments' 'comment' 'methods' 'method' )).
	"the interface exists, with its root fields"
	interface := (introspected at: 'types') detect: [ :t | (t at: 'name') = 'TWithComments' ] ifNone: [ nil ].
	self assert: interface notNil.
	self assert: (interface at: 'kind') equals: 'INTERFACE'.
	self assert: ((interface at: 'description') includesSubstring: 'interface').
	concept := builder sortedInterfaceConcepts detect: [ :c | c typeName = 'TWithComments' ].
	self assert: (queryFieldNames includes: concept listFieldName).
	self assert: (queryFieldNames includes: concept byIdFieldName).
	self
		assert: (self kindsOf: ((queryFields detect: [ :f | (f at: 'name') = concept listFieldName ]) at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'INTERFACE' 'TWithComments' ).
	self
		assert: (self kindsOf: ((queryFields detect: [ :f | (f at: 'name') = concept byIdFieldName ]) at: 'type'))
		equals: #( 'INTERFACE' 'TWithComments' ).
	self assert: ((self fieldsOfType: 'TWithComments' in: introspected) keys includesAll: #( 'id' 'name' 'type' )).
	commentFields := self fieldsOfType: 'Comment' in: introspected.
	self
		assert: (self kindsOf: ((commentFields at: 'commentedEntity') at: 'type'))
		equals: #( 'INTERFACE' 'TWithComments' ).
	"Class.comments and Method.comments are typed with the single concrete Comment concept"
	self
		assert: (self kindsOf: (((self fieldsOfType: 'Class' in: introspected) at: 'comments') at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Comment' ).
	data := self dataFrom: (self query: '{ comments { commentedEntity { __typename type name } } }' variables: nil on: schema model: commented).
	self assert: ((data at: 'comments') collect: [ :c | (c at: 'commentedEntity') at: 'type' ]) asSet equals: #( 'Class' 'Method' ) asSet.
	self assert: ((data at: 'comments') collect: [ :c | (c at: 'commentedEntity') at: 'name' ]) asSet equals: #( 'CommentedClass' 'commentedMethod' ) asSet.
	self assert: ((data at: 'comments') collect: [ :c | (c at: 'commentedEntity') at: '__typename' ]) asSet equals: #( 'Class' 'Method' ) asSet.
	"the interface list root field answers the entities of both conforming classes"
	data := self dataFrom: (self query: '{ ' , concept listFieldName , ' { __typename name } }' variables: nil on: schema model: commented).
	self assert: ((data at: concept listFieldName) collect: [ :e | e at: '__typename' ]) asSet equals: #( 'Class' 'Method' ) asSet
]

{ #category : 'tests' }
MGModelSchemaTest >> testInterfaceRootFields [
	"An interface concept has a list root field answering the entities of all its conforming concrete classes (with take) and a by-id root field answering a conforming entity with its concrete __typename, or null for an entity that does not conform"

	| builder schema named tMethod data classId methodId byId |
	builder := MGModelSchemaBuilder on: model.
	schema := builder build.
	named := builder sortedInterfaceConcepts detect: [ :c | c typeName = 'NamedEntity' ].
	tMethod := builder sortedInterfaceConcepts detect: [ :c | c typeName = 'TMethod' ].
	self assert: named listFieldName equals: 'namedEntities'.
	self assert: named byIdFieldName equals: 'namedEntity'.
	data := self dataFrom: (self
		query: '{ namedEntities { __typename name } two: namedEntities(take: 2) { name } classes { id name } methods { id name } }'
		variables: nil on: schema model: model).
	self assert: (data at: 'namedEntities') size equals: 6.
	self
		assert: ((data at: 'namedEntities') collect: [ :e | e at: 'name' ]) asSet
		equals: #( 'Class1' 'Class2' 'm1' 'm2' 'm3' 'a1' ) asSet.
	self
		assert: ((data at: 'namedEntities') collect: [ :e | e at: '__typename' ]) asSet
		equals: #( 'Attribute' 'Class' 'Method' ) asSet.
	self assert: (data at: 'two') size equals: 2.
	classId := ((data at: 'classes') detect: [ :e | (e at: 'name') = 'Class1' ]) at: 'id'.
	methodId := ((data at: 'methods') detect: [ :e | (e at: 'name') = 'm1' ]) at: 'id'.
	byId := self dataFrom: (self
		query: 'query ById($c: ID!, $m: ID!) { named: namedEntity(id: $c) { __typename name } method: ' , tMethod byIdFieldName , '(id: $m) { __typename name } notAMethod: ' , tMethod byIdFieldName , '(id: $c) { __typename name } }'
		variables: (Dictionary new at: 'c' put: classId; at: 'm' put: methodId; yourself)
		on: schema model: model).
	self assert: ((byId at: 'named') at: '__typename') equals: 'Class'.
	self assert: ((byId at: 'named') at: 'name') equals: 'Class1'.
	self assert: ((byId at: 'method') at: '__typename') equals: 'Method'.
	self assert: ((byId at: 'method') at: 'name') equals: 'm1'.
	self assert: (byId at: 'notAMethod') isNil
]

{ #category : 'tests' }
MGModelSchemaTest >> testIsCompatibleImplementationOf [
	"A field implements an interface field when it has the same name, kind and multiplicity, and the same scalar or a target conforming to the interface field target (any target when the latter is nil, i.e. MooseEntity)"

	| string superInterface subInterface object relation |
	string := MGConceptField scalarNamed: 'x' property: nil scalarName: 'String' multivalued: false.
	self assert: (string isCompatibleImplementationOf: string).
	self deny: ((MGConceptField scalarNamed: 'x' property: nil scalarName: 'Number' multivalued: false) isCompatibleImplementationOf: string).
	self deny: ((MGConceptField scalarNamed: 'x' property: nil scalarName: 'String' multivalued: true) isCompatibleImplementationOf: string).
	self deny: ((MGConceptField scalarNamed: 'other' property: nil scalarName: 'String' multivalued: false) isCompatibleImplementationOf: string).
	self deny: ((MGConceptField relationNamed: 'x' property: nil target: nil multivalued: false) isCompatibleImplementationOf: string).
	superInterface := MGConcept interfaceType: nil conformingClasses: #(  ).
	superInterface interfaces: #(  ).
	subInterface := MGConcept interfaceType: nil conformingClasses: #(  ).
	subInterface interfaces: { superInterface }.
	object := MGConcept objectType: nil conformingClasses: #(  ).
	object interfaces: { subInterface. superInterface }.
	relation := [ :target | MGConceptField relationNamed: 'r' property: nil target: target multivalued: true ].
	self assert: ((relation value: object) isCompatibleImplementationOf: (relation value: nil)).
	self assert: ((relation value: object) isCompatibleImplementationOf: (relation value: superInterface)).
	self assert: ((relation value: subInterface) isCompatibleImplementationOf: (relation value: superInterface)).
	self assert: ((relation value: superInterface) isCompatibleImplementationOf: (relation value: superInterface)).
	self deny: ((relation value: superInterface) isCompatibleImplementationOf: (relation value: subInterface)).
	self deny: ((relation value: nil) isCompatibleImplementationOf: (relation value: superInterface)).
	self deny: ((relation value: object) isCompatibleImplementationOf: (MGConceptField relationNamed: 'r' property: nil target: nil multivalued: false))
]

{ #category : 'tests' }
MGModelSchemaTest >> testListFieldsAndTake [
	"classes answers the 2 classes, methods the 3 methods, attributes the attribute; take: limits the lists, including relation lists"

	| data |
	data := self modelDataOf:
		        '{ classes { id name type __typename } methods { name type } attributes { name } oneClass: classes(take: 1) { name } twoMethods: methods(take: 2) { name } zero: methods(take: 0) { name } c: classes { name methods(take: 1) { name } } }'.
	self
		assert: ((data at: 'classes') collect: [ :c | c at: 'name' ]) asSet
		equals: #( 'Class1' 'Class2' ) asSet.
	self assert: ((data at: 'classes') allSatisfy: [ :c |
				 (c at: 'type') = 'Class' and: [
					 (c at: '__typename') = 'Class' and: [ (c at: 'id') isString ] ] ]).
	self
		assert: ((data at: 'methods') collect: [ :m | m at: 'name' ]) asSet
		equals: #( 'm1' 'm2' 'm3' ) asSet.
	self assert:
		((data at: 'methods') allSatisfy: [ :m | (m at: 'type') = 'Method' ]).
	self
		assert:
		((data at: 'attributes') collect: [ :a | a at: 'name' ]) asArray
		equals: #( 'a1' ).
	self assert: (data at: 'oneClass') size equals: 1.
	self assert: (data at: 'twoMethods') size equals: 2.
	self assert: (data at: 'zero') isEmpty.
	self assert:
		((data at: 'c') allSatisfy: [ :c | (c at: 'methods') size = 1 ])
]

{ #category : 'tests' }
MGModelSchemaTest >> testMooseEntityInterface [
	"MooseEntity is an INTERFACE with the 9 generic fields (children and ancestors take an optional take: Int); its possible types are the concepts, and every concept OBJECT type implements it first (then its supertype interfaces)"

	| response iface fields objects |
	response := self dataFrom: (self
			             query: '{ __type(name: "MooseEntity") { kind possibleTypes { name } fields { name args { name type { kind name ofType { kind name } } } type { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } __schema { types { kind name interfaces { name } } } }'
			             variables: nil on: self modelSchema model: model).
	iface := response at: '__type'.
	self assert: (iface at: 'kind') equals: 'INTERFACE'.
	self assert: ((iface at: 'possibleTypes') collect: [ :t | t at: 'name' ]) asSet equals: #( 'Attribute' 'Class' 'Method' ) asSet.
	fields := Dictionary new.
	(iface at: 'fields') do: [ :f | fields at: (f at: 'name') put: f ].
	self assert: (iface at: 'fields') size equals: 9.
	self assert: fields keys asSet equals: MGModelSchemaBuilder genericFieldNames asSet.
	{
		('id' -> #( 'NON_NULL' 'SCALAR' 'ID' )).
		('name' -> #( 'SCALAR' 'String' )).
		('type' -> #( 'SCALAR' 'String' )).
		('types' -> #( 'NON_NULL' 'LIST' 'NON_NULL' 'SCALAR' 'String' )).
		('container' -> #( 'INTERFACE' 'MooseEntity' )).
		('containers' -> #( 'NON_NULL' 'LIST' 'NON_NULL' 'INTERFACE' 'MooseEntity' )).
		('children' -> #( 'NON_NULL' 'LIST' 'NON_NULL' 'INTERFACE' 'MooseEntity' )).
		('childrenCount' -> #( 'SCALAR' 'Int' )).
		('ancestors' -> #( 'NON_NULL' 'LIST' 'NON_NULL' 'INTERFACE' 'MooseEntity' )) } do: [ :pair |
		self assert: (self kindsOf: ((fields at: pair key) at: 'type')) equals: pair value ].
	#( 'children' 'ancestors' ) do: [ :n |
		| args |
		args := (fields at: n) at: 'args'.
		self assert: (args collect: [ :a | a at: 'name' ]) asArray equals: #( 'take' ).
		self assert: (self kindsOf: (args first at: 'type')) equals: #( 'SCALAR' 'Int' ) ].
	#( 'id' 'name' 'type' 'types' 'container' 'containers' 'childrenCount' ) do: [ :n |
		self assert: ((fields at: n) at: 'args') isEmpty ].
	objects := ((response at: '__schema') at: 'types') select: [ :t |
		           (t at: 'kind') = 'OBJECT' and: [ (t at: 'name') ~= 'Query' and: [ ((t at: 'name') beginsWith: '__') not ] ] ].
	self assert: (objects collect: [ :t | t at: 'name' ]) asSet equals: #( 'Attribute' 'Class' 'Method' ) asSet.
	objects do: [ :t |
		self assert: ((t at: 'interfaces') collect: [ :i | i at: 'name' ]) first equals: 'MooseEntity' ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testNamingCollisionFallsBackToFullName [
	"Two concepts sharing the short FM3 name (Class of FamixTest1 and Class of FamixSt) both fall back to their sanitized fullName;
	a concept alone with its short name keeps it.
	A realistic model mixing both metamodels cannot be built (entities of a foreign metamodel are ignored), so the naming helper is unit-tested"

	| builder test1Class stClass test1Method byShortName |
	builder := MGModelSchemaBuilder on: model.
	test1Class := MGConcept
		              rootType: FamixTest1Class new metadescription
		              conformingClasses: #(  ).
	stClass := MGConcept
		           rootType: FamixStClass new metadescription
		           conformingClasses: #(  ).
	test1Method := MGConcept
		               rootType: FamixTest1Method new metadescription
		               conformingClasses: #(  ).
	byShortName := {
		               test1Class.
		               stClass.
		               test1Method } groupedBy: [ :c | c shortName ].
	self
		assert: (builder preferredTypeNameOf: test1Class among: byShortName)
		equals: 'FamixTest1Entities_Class'.
	self
		assert: (builder preferredTypeNameOf: stClass among: byShortName)
		equals: 'FamixPharoSmalltalkEntities_Class'.
	self
		assert:
		(builder preferredTypeNameOf: test1Method among: byShortName)
		equals: 'Method'
]

{ #category : 'tests' }
MGModelSchemaTest >> testNumberValuesAreIntegers [
	"FM3 Number properties use the custom Number scalar, which keeps integers (not serialized as Floats or Strings)"

	| fields data class1Data |
	fields := self fieldsOfType: 'Class' in: self introspectedSchema.
	self
		assert: (self kindsOf: ((fields at: 'numberOfMethods') at: 'type'))
		equals: #( 'SCALAR' 'Number' ).
	self
		assert: (self kindsOf: ((fields at: 'isStub') at: 'type'))
		equals: #( 'SCALAR' 'Boolean' ).
	data := self modelDataOf:
		        '{ classes { name numberOfMethods numberOfAttributes isStub } }'.
	class1Data := (data at: 'classes') detect: [ :c |
		              (c at: 'name') = 'Class1' ].
	self assert: (class1Data at: 'numberOfMethods') equals: 2.
	self assert: (class1Data at: 'numberOfMethods') isInteger.
	self assert: (class1Data at: 'numberOfAttributes') equals: 1.
	self assert: (class1Data at: 'numberOfAttributes') isInteger.
	self assert: (class1Data at: 'isStub') equals: false.
	"the serializer itself"
	self assert: (MGModelSchemaBuilder serializeNumber: 42) equals: 42.
	self assert: (MGModelSchemaBuilder serializeNumber: 42) isInteger.
	self
		assert: (MGModelSchemaBuilder serializeNumber: 1 / 2)
		equals: 0.5.
	self assert:
		(MGModelSchemaBuilder serializeNumber: Float infinity) isNil.
	self assert: (MGModelSchemaBuilder serializeNumber: 'x') isNil
]

{ #category : 'tests - temporal' }
MGModelSchemaTest >> testObjectPropertyWithDateAndTimesIsDateTime [
	"AnnotationInstanceAttribute.value is typed Object (FM3Object): when its sampled values are only DateAndTimes it becomes a DateTime scalar field (not a relation),
	values are serialized in ISO 8601 keeping their offset, nil answers null, and the Object helper type is not defined since nothing uses it"

	| result |
	result := self
		          valueTypeAndDataOf: (self annotationModelWithValues: {
					           (DateAndTime
						            year: 2017
						            month: 7
						            day: 4
						            hour: 4
						            minute: 5
						            second: 6
						            offset: (Duration hours: 2)).
					           (DateAndTime
						            year: 2020
						            month: 1
						            day: 31
						            hour: 23
						            minute: 59
						            second: 0
						            nanoSecond: 500000000
						            offset: Duration zero).
					           nil })
		          selection: ''.
	self assert: result first equals: #( 'SCALAR' 'DateTime' ).
	self deny: (result second includes: 'Object').
	self assert: (result second includesAll:
			 #( 'Date' 'Time' 'DateTime' 'Duration' 'Number' )).
	self
		assert: result third asBag
		equals:
			#( '2017-07-04T04:05:06+02:00' '2020-01-31T23:59:00.5+00:00'
			   nil ) asBag
]

{ #category : 'tests' }
MGModelSchemaTest >> testObjectPropertyWithEntitiesStaysRelation [
	"Object-typed values that are only entities keep the property a relation; the declared type Object being built-in, it is typed with the MooseEntity interface, resolving to the entities"

	| result entities |
	result := self
		valueTypeAndDataOf: (self annotationModelWithValues: { [ :m | m allClasses first ]. [ :m | m allClasses first ]. nil })
		selection: ' { type name }'.
	self assert: result first equals: #( 'INTERFACE' 'MooseEntity' ).
	self deny: (result second includes: 'Object').
	self assert: (result third count: [ :v | v isNil ]) equals: 1.
	entities := result third reject: [ :v | v isNil ].
	self assert: entities size equals: 2.
	entities do: [ :v |
		self assert: (v at: 'type') equals: 'Class'.
		self assert: (v at: 'name') equals: 'Foo' ]
]

{ #category : 'tests - temporal' }
MGModelSchemaTest >> testObjectPropertyWithMixedValuesIsString [
	"Object-typed values of several kinds (an entity with a Date, two temporal kinds, Strings with Numbers) give a String field printing each value (temporal values in ISO 8601);
	values of one plain kind give that scalar.
	The entity value is the named FamixStClass Foo: it must print as its name 'Foo', never as its bare mooseID"

	| annotationModel foo result |
	annotationModel := self annotationModelWithValues: {
			         [ :m | m allClasses detect: [ :c | c name = 'Foo' ] ].
			         (Date year: 2017 month: 7 day: 4) }.
	foo := annotationModel allClasses detect: [ :c | c name = 'Foo' ].
	result := self valueTypeAndDataOf: annotationModel selection: ''.
	self assert: result first equals: #( 'SCALAR' 'String' ).
	self deny: (result second includes: 'Object').
	self assert: (result third allSatisfy: [ :v | v isString ]).
	self assert: result third asBag equals: #( 'Foo' '2017-07-04' ) asBag.
	self deny: (result third includes: foo mooseID printString).
	result := self
		          valueTypeAndDataOf: (self annotationModelWithValues: {
					           (Date year: 2017 month: 7 day: 4).
					           (Duration seconds: 5) })
		          selection: ''.
	self assert: result first equals: #( 'SCALAR' 'String' ).
	self
		assert: result third asBag
		equals: #( '2017-07-04' 'PT5S' ) asBag.
	result := self
		          valueTypeAndDataOf:
		          (self annotationModelWithValues: #( 'x' 3 ))
		          selection: ''.
	self assert: result first equals: #( 'SCALAR' 'String' ).
	self assert: result third asBag equals: #( 'x' '3' ) asBag.
	result := self
		          valueTypeAndDataOf:
		          (self annotationModelWithValues: #( 4 3 ))
		          selection: ''.
	self assert: result first equals: #( 'SCALAR' 'Number' ).
	self assert: result third asBag equals: #( 4 3 ) asBag.
	result := self
		          valueTypeAndDataOf:
		          (self annotationModelWithValues: #( true false ))
		          selection: ''.
	self assert: result first equals: #( 'SCALAR' 'Boolean' ).
	self assert: result third asBag equals: #( true false ) asBag.
	result := self
		          valueTypeAndDataOf:
		          (self annotationModelWithValues: #( 'a' 'b' ))
		          selection: ''.
	self assert: result first equals: #( 'SCALAR' 'String' ).
	self assert: result third asBag equals: #( 'a' 'b' ) asBag
]

{ #category : 'tests - temporal' }
MGModelSchemaTest >> testObjectPropertyWithOtherTemporalKinds [
	"Object-typed values that are only Dates, only Times or only Durations give the Date, Time or Duration scalar, serialized in ISO 8601"

	{
		({
			 (Date year: 2017 month: 7 day: 4).
			 (Date year: 2016 month: 2 day: 29) }
		 -> #( 'Date' #( '2017-07-04' '2016-02-29' ) )).
		({
			 (Time hour: 4 minute: 5 second: 6).
			 (Time
				  hour: 16
				  minute: 5
				  second: 6
				  nanoSecond: 250000000) }
		 -> #( 'Time' #( '04:05:06' '16:05:06.25' ) )).
		({
			 (Duration seconds: -5).
			 Duration zero.
			 (Duration
				  days: 1
				  hours: 2
				  minutes: 3
				  seconds: 4) }
		 -> #( 'Duration' #( '-PT5S' 'PT0S' 'P1DT2H3M4S' ) )) } do: [ :each |
			| result |
			result := self
				          valueTypeAndDataOf:
				          (self annotationModelWithValues: each key)
				          selection: ''.
			self assert: result first equals: {
					'SCALAR'.
					each value first }.
			self deny: (result second includes: 'Object').
			self assert: result third asBag equals: each value second asBag ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testObjectPropertyWithoutValuesStaysRelation [
	"With no value to sample (all nil), an Object-typed property stays a relation typed with the MooseEntity interface, resolving to null"

	| result |
	result := self valueTypeAndDataOf: (self annotationModelWithValues: #( nil nil )) selection: ' { id }'.
	self assert: result first equals: #( 'INTERFACE' 'MooseEntity' ).
	self deny: (result second includes: 'Object').
	self assert: result third asArray equals: #( nil nil )
]

{ #category : 'tests' }
MGModelSchemaTest >> testObjectTypesAreModelConcepts [
	"The object types are exactly the concrete concepts having instances in the fixture model; the generic types are not object types, and Entity (FamixTest1 superclass of all the concepts) is an interface"

	| schema names |
	self assert: (self modelSchema isKindOf: GQLSchema).
	schema := self introspectedSchema.
	self assert: ((schema at: 'queryType') at: 'name') equals: 'Query'.
	names := (self conceptObjectTypesOf: schema) collect: [ :t | t at: 'name' ].
	self assert: names asSet equals: #( 'Attribute' 'Class' 'Method' ) asSet.
	#( 'Entity' 'MetaClass' 'Model' 'Property' 'Relation' ) do: [ :generic |
		self deny: ((schema at: 'types') anySatisfy: [ :t | (t at: 'name') = generic and: [ (t at: 'kind') = 'OBJECT' ] ]) ].
	self assert: (((schema at: 'types') detect: [ :t | (t at: 'name') = 'Entity' ]) at: 'kind') equals: 'INTERFACE'
]

{ #category : 'tests' }
MGModelSchemaTest >> testObjectsImplementTransitiveSupertypes [
	"Each object implements MooseEntity first, then the interfaces of all its FM3 supertypes (superclasses and traits, without built-in and Moose base types) in the order of MGRegistry>>#allSupertypesOf:; an interface lists its own supertype interfaces too; every type implements the interfaces of its interfaces (GraphQL validity rule)"

	| builder classConcept expected types interfacesByName |
	builder := MGModelSchemaBuilder on: model.
	builder build.
	classConcept := builder rootConcepts detect: [ :c | c typeName = 'Class' ].
	expected := OrderedCollection with: 'MooseEntity'.
	((MGRegistry forModel: model) allSupertypesOf: classConcept fm3Type) do: [ :type |
		(builder isInterfaceCandidate: type) ifTrue: [
			expected add: (builder sortedInterfaceConcepts detect: [ :i | i fm3Type == type ]) typeName ] ].
	self assert: expected size > 2.
	types := ((self dataFrom: (self
		query: '{ __schema { types { kind name interfaces { name } } } }'
		variables: nil on: self modelSchema model: model)) at: '__schema') at: 'types'.
	interfacesByName := Dictionary new.
	types do: [ :t |
		(t at: 'interfaces') ifNotNil: [ :list |
			interfacesByName at: (t at: 'name') put: (list collect: [ :i | i at: 'name' ]) asArray ] ].
	self assert: (interfacesByName at: 'Class') equals: expected asArray.
	self assert: (interfacesByName at: 'NamedEntity') first equals: 'MooseEntity'.
	self assert: ((interfacesByName at: 'NamedEntity') includesAll: #( 'Entity' 'TNamedEntity' )).
	interfacesByName keysAndValuesDo: [ :typeName :names |
		names do: [ :each |
			self
				assert: (names includesAll: (interfacesByName at: each))
				description: [ typeName , ' does not implement all the interfaces of ' , each ] ] ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testQueryFields [
	"Each object concept has a plural lowerFirst list field and a singular lowerFirst by-id field typed with the object (unchanged); plus the generic rootEntities field; every other Query field is a root field of an interface concept, typed with that interface"

	| fields objectFieldNames others |
	fields := (self introspectedSchema at: 'queryType') at: 'fields'.
	objectFieldNames := #( 'attributes' 'attribute' 'classes' 'class' 'methods' 'method' ) asSet.
	self
		assert: ((fields select: [ :f | (self kindsOf: (f at: 'type')) includes: 'OBJECT' ]) collect: [ :f | f at: 'name' ]) asSet
		equals: objectFieldNames.
	self assert: ((fields collect: [ :f | f at: 'name' ]) includes: 'rootEntities').
	others := fields reject: [ :f | (objectFieldNames includes: (f at: 'name')) or: [ (f at: 'name') = 'rootEntities' ] ].
	self assert: others notEmpty.
	others do: [ :f |
		| kinds |
		kinds := self kindsOf: (f at: 'type').
		self assert: (kinds at: kinds size - 1) equals: 'INTERFACE'.
		self deny: kinds last equals: 'MooseEntity' ].
	self assert: ((others collect: [ :f | f at: 'name' ]) includesAll: #( 'namedEntities' 'namedEntity' )).
	self assert: fields size equals: others size + objectFieldNames size + 1
]

{ #category : 'tests' }
MGModelSchemaTest >> testRegistryForModel [
	"MGRegistry forModel: only knows the served model; instancesOfAll:model:take: and entityAt:ofAnyOf: filter by concrete FM3 classes"

	| reg classFM3 methodFM3 |
	reg := MGRegistry forModel: model.
	self assert: reg models asArray equals: { model }.
	classFM3 := class1 metadescription.
	methodFM3 := m1 metadescription.
	self
		assert:
		(reg instancesOfAll: { classFM3 } model: model take: nil) asSet
		equals: {
				class1.
				class2 } asSet.
	self
		assert: (reg
				 instancesOfAll: {
						 classFM3.
						 methodFM3 }
				 model: model
				 take: nil) size
		equals: 5.
	self
		assert:
		(reg instancesOfAll: { methodFM3 } model: model take: 2) size
		equals: 2.
	self
		assert: (reg entityAt: (reg idOfEntity: m1) ofAnyOf: { methodFM3 })
		identicalTo: m1.
	self assert:
		(reg entityAt: (reg idOfEntity: m1) ofAnyOf: { classFM3 }) isNil.
	self assert: (reg entityAt: 'nope' ofAnyOf: { classFM3 }) isNil
]

{ #category : 'tests' }
MGModelSchemaTest >> testRelationTyping [
	"A relation whose declared type is satisfied by exactly one concrete class of the model is typed with that concept:
	Class.methods: [Method!]! (with take: Int), Class.attributes: [Attribute!]!, Method.parentType: Class, Attribute.parentType: Class"

	| schema classFields methodFields attributeFields take |
	schema := self introspectedSchema.
	classFields := self fieldsOfType: 'Class' in: schema.
	methodFields := self fieldsOfType: 'Method' in: schema.
	attributeFields := self fieldsOfType: 'Attribute' in: schema.
	self
		assert: (self kindsOf: ((classFields at: 'methods') at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Method' ).
	self
		assert: (self kindsOf: ((classFields at: 'attributes') at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Attribute' ).
	self
		assert: (self kindsOf: ((methodFields at: 'parentType') at: 'type'))
		equals: #( 'OBJECT' 'Class' ).
	self
		assert:
		(self kindsOf: ((attributeFields at: 'parentType') at: 'type'))
		equals: #( 'OBJECT' 'Class' ).
	"multivalued relations accept take: Int (args are not fetched by introspectedSchema: check through a query)"
	take := self modelDataOf:
		        '{ __type(name: "Class") { fields { name args { name type { kind name } } } } }'.
	take := ((take at: '__type') at: 'fields') detect: [ :f |
		        (f at: 'name') = 'methods' ].
	self
		assert: ((take at: 'args') collect: [ :a | a at: 'name' ]) asArray
		equals: #( 'take' )
]

{ #category : 'tests' }
MGModelSchemaTest >> testRelationsWithoutConformingConceptAreDropped [
	"Relations whose declared type has no concrete class with instances in the model can only be empty and are not exposed:
	comments, tags and source anchors among others (the primitive hasComments/numberOfComments/isTagged stay)"

	| schema |
	schema := self introspectedSchema.
	#( 'Attribute' 'Class' 'Method' ) do: [ :typeName |
			| names |
			names := (self fieldsOfType: typeName in: schema) keys.
			#( 'comments' 'allTagAssociations' 'sourceAnchor' 'declaredSourceLanguage'
			   'replicas' 'typing' 'incomingReferences' 'superInheritances'
			   'subInheritances' 'parentPackage' 'outgoingInvocations'
			   'incomingInvocations' 'incomingAccesses' 'accesses' 'parameters' )
				do: [ :dropped |
						self
							deny: (names includes: dropped)
							description: typeName , '.' , dropped , ' should be dropped' ] ].
	self assert: ((self fieldsOfType: 'Class' in: schema) includesKey:
			 'numberOfComments')
]

{ #category : 'tests' }
MGModelSchemaTest >> testReservedNamesAndNameHelpers [
	"Reserved names (GraphQL built-ins, Query, Number, the temporal scalars Date, Time, DateTime and Duration, __*) fall back to the sanitized fullName, and names are made unique and valid"

	| builder query byShortName used |
	builder := MGModelSchemaBuilder on: model.
	#( 'Query' 'String' 'Int' 'Float' 'Boolean' 'ID' 'Number' 'Date' 'Time' 'DateTime' 'Duration' '__Type' )
		do: [ :n |
		self assert: (builder isReservedTypeName: n) description: n ].
	self deny: (builder isReservedTypeName: 'Class').
	self deny: (builder isReservedTypeName: 'DateAndTime').
	"a concept named Query in package My-Pkg is renamed after its fullName"
	query := MGConcept
		         rootType: (FM3Class new
				          name: #Query;
				          package: (FM3Package new
						           name: #'My-Pkg';
						           yourself);
				          yourself)
		         conformingClasses: #(  ).
	byShortName := { query } groupedBy: [ :c | c shortName ].
	self
		assert: (builder preferredTypeNameOf: query among: byShortName)
		equals: 'MyPkg_Query'.
	"uniqueName:among:alternative: never answers a used name"
	used := Set withAll: MGModelSchemaBuilder reservedTypeNames.
	self
		assert: (builder uniqueName: 'Query' among: used alternative: '')
		equals: 'Query2'.
	self assert: (used includes: 'Query2').
	used := Set withAll: #( 'class' 'classById' ).
	self
		assert:
		(builder uniqueName: 'class' among: used alternative: 'ById')
		equals: 'classById2'.
	self
		assert:
		(builder uniqueName: 'method' among: used alternative: 'ById')
		equals: 'method'.
	"graphQLNameFrom: answers valid GraphQL names"
	self
		assert: (builder graphQLNameFrom: 'Famix-Test1-Entities.Entity')
		equals: 'FamixTest1Entities_Entity'.
	self assert: (builder graphQLNameFrom: '9abc') equals: 'T9abc'.
	self assert: (builder graphQLNameFrom: '__x') equals: 'T__x'.
	self assert: (builder graphQLNameFrom: '') equals: 'T'.
	self assert: (builder graphQLNameFrom: 'a:b c') equals: 'a_bc'.
	"pluralOf:"
	self
		assert:
			(#( 'class' 'method' 'access' 'entity' 'property' 'box' 'match'
			    'flash' 'key' ) collect: [ :n | builder pluralOf: n ])
		equals:
			#( 'classes' 'methods' 'accesses' 'entities' 'properties'
			   'boxes' 'matches' 'flashes' 'keys' )
]

{ #category : 'tests' }
MGModelSchemaTest >> testReservedTypeNamesIncludeMooseEntity [
	"MooseEntity is the generic interface: no concept may take its name"

	self assert: (MGModelSchemaBuilder reservedTypeNames includes: 'MooseEntity').
	self assert: (MGModelSchemaBuilder reservedTypeNames includes: 'Query')
]

{ #category : 'tests' }
MGModelSchemaTest >> testRootEntities [
	"rootEntities(take: Int) answers the entities without container (Class1 and Class2), typed with their concrete concept, as a list of MooseEntity"

	| data field |
	data := self dataFrom: (self
			         query: '{ rootEntities { __typename name type } first: rootEntities(take: 1) { name } }'
			         variables: nil on: self modelSchema model: model).
	self assert: (data at: 'rootEntities') size equals: 2.
	self assert: ((data at: 'rootEntities') collect: [ :e | e at: 'name' ]) asSet equals: #( 'Class1' 'Class2' ) asSet.
	self assert: ((data at: 'rootEntities') allSatisfy: [ :e | (e at: '__typename') = 'Class' and: [ (e at: 'type') = 'Class' ] ]).
	self assert: (data at: 'first') size equals: 1.
	field := ((self introspectedSchema at: 'queryType') at: 'fields') detect: [ :f | (f at: 'name') = 'rootEntities' ].
	self assert: (self kindsOf: (field at: 'type')) equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'INTERFACE' 'MooseEntity' ).
	self assert: ((field at: 'args') collect: [ :a | a at: 'name' ]) asArray equals: #( 'take' ).
	self assert: (self kindsOf: ((field at: 'args') first at: 'type')) equals: #( 'SCALAR' 'Int' )
]

{ #category : 'tests' }
MGModelSchemaTest >> testRootFieldsAnswerExactClass [
	"Each concept list field answers the instances of exactly the concept class (the fixture has no instance of a subclass, so counts are the exact-class counts)"

	| data |
	data := self dataFrom: (self
			         query: '{ classes { type } methods { type } attributes { type } }'
			         variables: nil on: self modelSchema model: model).
	{
		{ 'classes'. FamixTest1Class. 'Class'. 2 }.
		{ 'methods'. FamixTest1Method. 'Method'. 3 }.
		{ 'attributes'. FamixTest1Attribute. 'Attribute'. 1 } } do: [ :spec |
		self assert: (data at: spec first) size equals: spec fourth.
		self assert: (data at: spec first) size equals: (model entities count: [ :e | e class == spec second ]).
		self assert: ((data at: spec first) allSatisfy: [ :e | (e at: 'type') = spec third ]) ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testSchemaConventionsForEachRootConcept [
	"Fluid UI contract (see MGSchemaTest>>#testSchemaConventions) for every root concept T:
	- the list field is [T!]! with an optional take: Int
	- the by-id field is T with a mandatory id: ID!"

	| fields byName |
	fields := (self introspectedSchema at: 'queryType') at: 'fields'.
	byName := Dictionary new.
	fields do: [ :f | byName at: (f at: 'name') put: f ].
	{
		('Attribute' -> #( 'attributes' 'attribute' )).
		('Class' -> #( 'classes' 'class' )).
		('Method' -> #( 'methods' 'method' )) } do: [ :assoc |
			| list byId take idArg |
			list := byName at: assoc value first.
			self assert: (self kindsOf: (list at: 'type')) equals: {
					'NON_NULL'.
					'LIST'.
					'NON_NULL'.
					'OBJECT'.
					assoc key }.
			take := (list at: 'args')
				        detect: [ :a | (a at: 'name') = 'take' ]
				        ifNone: [ nil ].
			self
				assert: take notNil
				description: assoc value first , ' has no take argument'.
			self
				assert: (self kindsOf: (take at: 'type'))
				equals: #( 'SCALAR' 'Int' ).
			byId := byName at: assoc value second.
			self assert: (self kindsOf: (byId at: 'type')) equals: {
					'OBJECT'.
					assoc key }.
			idArg := (byId at: 'args')
				         detect: [ :a | (a at: 'name') = 'id' ]
				         ifNone: [ nil ].
			self
				assert: idArg notNil
				description: assoc value second , ' has no id argument'.
			self
				assert: (self kindsOf: (idArg at: 'type'))
				equals: #( 'NON_NULL' 'SCALAR' 'ID' ) ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testSweepAllScalarFieldsOfAllRootConcepts [
	"Resilience (see MGResilienceTest): every scalar field of every entity of every root concept resolves without error, on the fixture model and on the commented model"

	| data class1Data |
	data := self assertSweepOf: self modelSchema model: model.
	self assert: (data at: 'classes') size equals: 2.
	self assert: (data at: 'methods') size equals: 3.
	self assert: (data at: 'attributes') size equals: 1.
	class1Data := (data at: 'classes') detect: [ :c |
		              (c at: 'name') = 'Class1' ].
	"numberOfAbstractMethods raises internally: null, not an error"
	self assert: (class1Data includesKey: 'numberOfAbstractMethods').
	self assert: (class1Data at: 'numberOfAbstractMethods') isNil.
	self commentedModel in: [ :commented |
			self
				assertSweepOf: (MGModelSchemaBuilder buildFor: commented)
				model: commented ]
]

{ #category : 'tests - temporal' }
MGModelSchemaTest >> testSweepOfTemporalAndMixedModels [
	"Selecting all scalar fields (temporal value included) of every entity of models with temporal, mixed or missing Object values raises nothing and reports no GraphQL error"

	{
		{
			(DateAndTime
				 year: 2017
				 month: 7
				 day: 4
				 hour: 4
				 minute: 5
				 second: 6
				 offset: (Duration hours: -7)).
			nil }.
		{
			(Duration seconds: -5).
			(Duration days: 3) }.
		{
			(Date year: 2017 month: 7 day: 4).
			(Time hour: 4 minute: 5 second: 6).
			[ :m | m allClasses first ].
			'x'.
			42.
			nil } } do: [ :values |
			| annotationModel data |
			annotationModel := self annotationModelWithValues: values.
			data := self
				        assertSweepOf:
				        (MGModelSchemaBuilder buildFor: annotationModel)
				        model: annotationModel.
			self
				assert: (data at: 'annotationInstanceAttributes') size
				equals: values size ]
]

{ #category : 'tests - temporal' }
MGModelSchemaTest >> testTemporalScalarsCoercion [
	"The Date, Time, DateTime and Duration scalars are always defined (even when no property uses them);
	their coercion accepts a valid ISO 8601 String (answering the Pharo value) or a value of that kind, and signals GQLCoercionError otherwise"

	| schema |
	schema := MGModelSchemaBuilder buildFor: model.
	{
		('Date' -> {
			 '2017-07-04'.
			 (Date year: 2017 month: 7 day: 4).
			 '2017-02-30' }).
		('Time' -> {
			 '04:05:06'.
			 (Time hour: 4 minute: 5 second: 6).
			 '24:00' }).
		('DateTime' -> {
			 '2017-07-04T04:05:06Z'.
			 (DateAndTime
				  year: 2017
				  month: 7
				  day: 4
				  hour: 4
				  minute: 5
				  second: 6
				  offset: Duration zero).
			 '2017-07-04' }).
		('Duration' -> {
			 'PT5S'.
			 (Duration seconds: 5).
			 'P1Y' }) } do: [ :each |
			| type |
			type := schema typeNamed: each key.
			self assert: type notNil description: each key.
			self assert: type isScalar.
			self
				assert: (type coerce: each value first)
				equals: each value second.
			self
				assert: (type coerce: each value second)
				equals: each value second.
			self
				assert:
				(MGModelSchemaBuilder
					 coerceTemporal: each value first
					 as: each key)
				equals: each value second.
			self assert:
				(MGModelSchemaBuilder
					 coerceTemporal: each value third
					 as: each key) isNil.
			self
				should: [ type coerce: each value third ]
				raise: GQLCoercionError.
			self should: [ type coerce: 42 ] raise: GQLCoercionError.
			self should: [ type coerce: 'garbage' ] raise: GQLCoercionError ].
	"a value of another temporal kind is rejected too"
	self
		should: [ (schema typeNamed: 'Date') coerce: (Duration seconds: 5) ]
		raise: GQLCoercionError
]

{ #category : 'tests - temporal' }
MGModelSchemaTest >> testTemporalSerializerMismatchAnswersNil [
	"serializeTemporal:as: answers the ISO 8601 String of a value of the right kind, a String already valid for that scalar as is, and nil (never raising) for anything else"

	| schema |
	self
		assert: (MGModelSchemaBuilder
				 serializeTemporal: (Date year: 2017 month: 7 day: 4)
				 as: 'Date')
		equals: '2017-07-04'.
	self
		assert: (MGModelSchemaBuilder
				 serializeTemporal: (Duration seconds: 5)
				 as: 'Duration')
		equals: 'PT5S'.
	self
		assert: (MGModelSchemaBuilder
				 serializeTemporal: '2017-07-04T04:05:06Z'
				 as: 'DateTime')
		equals: '2017-07-04T04:05:06Z'.
	{
		((Duration seconds: 5) -> 'Date').
		((Date year: 2017 month: 7 day: 4) -> 'DateTime').
		((Time hour: 4 minute: 5 second: 6) -> 'Duration').
		('2017-02-30' -> 'Date').
		('not a date' -> 'DateTime').
		(42 -> 'Time').
		(nil -> 'Date').
		(Object new -> 'Duration').
		(Month current -> 'Date').
		((Date year: 2017 month: 7 day: 4) -> 'Foo') } do: [ :each |
			self
				shouldnt: [
						self assert:
							(MGModelSchemaBuilder
								 serializeTemporal: each key
								 as: each value) isNil ]
				raise: Error ].
	"through the scalar types of a schema"
	schema := MGModelSchemaBuilder buildFor: model.
	self assert:
		((schema typeNamed: 'Date') serialize: (Duration seconds: 1)) isNil.
	self
		assert:
		((schema typeNamed: 'Duration') serialize: (Duration seconds: 1))
		equals: 'PT1S'
]

{ #category : 'helpers' }
MGModelSchemaTest >> valueTypeAndDataOf: anAnnotationModel selection: aSelectionString [
	"Build the schema of anAnnotationModel and answer an Array with: the kinds of AnnotationInstanceAttribute.value (see #kindsOf:), the set of the names of all the schema types, and the values of value for all attributes (aSelectionString is appended to value, e.g. '' or ' { id type }')"

	| schema introspected valueField data |
	schema := MGModelSchemaBuilder buildFor: anAnnotationModel.
	introspected := self
		                introspectedSchemaOf: schema
		                model: anAnnotationModel.
	valueField := (self
		               fieldsOfType: 'AnnotationInstanceAttribute'
		               in: introspected) at: 'value'.
	data := self dataFrom: (self
			         query:
			         '{ annotationInstanceAttributes { value'
			         , aSelectionString , ' } }'
			         variables: nil
			         on: schema
			         model: anAnnotationModel).
	^ {
		  (self kindsOf: (valueField at: 'type')).
		  ((introspected at: 'types') collect: [ :t | t at: 'name' ]) asSet.
		  ((data at: 'annotationInstanceAttributes') collect: [ :each |
			   each at: 'value' ]) }
]
