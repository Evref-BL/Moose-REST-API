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
MGModelSchemaTest >> assertSweepOf: aSchema model: aMooseModel [
	"Query every entity of every root concept selecting all its scalar fields (built from introspection); assert no exception escapes, no GraphQL error is reported and every list has the expected size.
	Some properties raise internally (e.g. numberOfAbstractMethods on FamixTest1Class): they must resolve to null, not to an error"

	| introspected rootFields query response data |
	introspected := self introspectedSchemaOf: aSchema model: aMooseModel.
	rootFields := ((introspected at: 'queryType') at: 'fields') select: [
		              :f | (self kindsOf: (f at: 'type')) includes: 'LIST' ].
	self assert: rootFields notEmpty.
	query := String streamContents: [ :s |
			         s nextPutAll: '{ '.
			         rootFields do: [ :f |
					         | typeName scalars |
					         typeName := (self kindsOf: (f at: 'type')) last.
					         scalars := (self fieldsOfType: typeName in: introspected)
						                    values select: [ :field |
						                    (self kindsOf: (field at: 'type'))
							                    includes: 'SCALAR' ].
					         s
						         nextPutAll: (f at: 'name');
						         nextPutAll: '(take: 1000) { '.
					         scalars
						         do: [ :field | s nextPutAll: (field at: 'name') ]
						         separatedBy: [ s space ].
					         s nextPutAll: ' } ' ].
			         s nextPutAll: '}' ].
	self
		shouldnt: [
				response := self
					            query: query
					            variables: nil
					            on: aSchema
					            model: aMooseModel ]
		raise: Error.
	data := self dataFrom: response.
	rootFields do: [ :f |
			| typeName |
			typeName := (self kindsOf: (f at: 'type')) last.
			self
				assert: (data at: (f at: 'name')) size
				equals: (aMooseModel entities count: [ :e |
							 ([ e metadescription name asString ]
								  on: Error
								  do: [ :err | err return: nil ]) = typeName ]).
			(data at: (f at: 'name')) do: [ :entity |
					self assert: (entity at: 'type') equals: typeName.
					self assert: (entity at: 'id') isString ] ].
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
MGModelSchemaTest >> testConcepts [
	"MGConcept describes the generated types: root concepts carry their root field names, helper concepts have none"

	| builder roots helpers helper |
	builder := MGModelSchemaBuilder on: self commentedModel.
	builder build.
	roots := builder concepts select: [ :c | c isRoot ].
	helpers := builder concepts select: [ :c | c isHelper ].
	self
		assert: (roots collect: [ :c | c typeName ]) asSet
		equals: #( 'Class' 'Comment' 'Method' ) asSet.
	self
		assert: (builder rootConcepts collect: [ :c | c typeName ]) asSet
		equals: (roots collect: [ :c | c typeName ]) asSet.
	(roots detect: [ :c | c typeName = 'Class' ]) in: [ :class |
			self assert: class listFieldName equals: 'classes'.
			self assert: class byIdFieldName equals: 'class'.
			self deny: class isHelper.
			self assert: class shortName equals: 'Class'.
			self assert: class fullName equals: 'Famix-Test1-Entities.Class' ].
	self assert: helpers size equals: 1.
	helper := helpers first.
	self assert: helper typeName equals: 'TWithComments'.
	self deny: helper isRoot.
	self assert: helper listFieldName isNil.
	self assert: helper byIdFieldName isNil.
	self
		assert:
		(helper conformingClasses collect: [ :c | c name asString ]) asSet
		equals: #( 'Class' 'Method' ) asSet.
	self assert: (helper description includesSubstring: 'Class, Method')
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
MGModelSchemaTest >> testHelperTypeForPolymorphicRelation [
	"Comment.commentedEntity is declared as FamixTWithComments, satisfied by both Class and Method in the commented model:
	it is typed with the hidden helper type TWithComments, which has the identity fields but no root field,
	and its values report their concrete concept through type"

	| commented schema introspected queryFieldNames commentFields helper data |
	commented := self commentedModel.
	schema := MGModelSchemaBuilder buildFor: commented.
	introspected := self introspectedSchemaOf: schema model: commented.
	queryFieldNames := (((introspected at: 'queryType') at: 'fields')
		                    collect: [ :f | f at: 'name' ]) asSet.
	self
		assert: queryFieldNames
		equals:
		#( 'classes' 'class' 'comments' 'comment' 'methods' 'method' ) asSet.
	"the helper type exists, with no root field"
	helper := (introspected at: 'types')
		          detect: [ :t | (t at: 'name') = 'TWithComments' ]
		          ifNone: [ nil ].
	self assert: helper notNil.
	self assert: (helper at: 'kind') equals: 'OBJECT'.
	self assert:
		((helper at: 'description') includesSubstring: 'polymorphic').
	self deny: (queryFieldNames anySatisfy: [ :n |
			 n asLowercase includesSubstring: 'withcomment' ]).
	self assert:
		(((introspected at: 'queryType') at: 'fields') noneSatisfy: [ :f |
			 (self kindsOf: (f at: 'type')) last = 'TWithComments' ]).
	self assert:
		((self fieldsOfType: 'TWithComments' in: introspected) keys
			 includesAll: #( 'id' 'name' 'type' )).
	commentFields := self fieldsOfType: 'Comment' in: introspected.
	self
		assert:
		(self kindsOf: ((commentFields at: 'commentedEntity') at: 'type'))
		equals: #( 'OBJECT' 'TWithComments' ).
	"Class.comments and Method.comments are typed with the single concrete Comment concept"
	self
		assert: (self kindsOf:
				 (((self fieldsOfType: 'Class' in: introspected) at: 'comments')
					  at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Comment' ).
	data := self dataFrom: (self
			         query:
			         '{ comments { commentedEntity { __typename type name } } }'
			         variables: nil
			         on: schema
			         model: commented).
	self
		assert: ((data at: 'comments') collect: [ :c |
				 (c at: 'commentedEntity') at: 'type' ]) asSet
		equals: #( 'Class' 'Method' ) asSet.
	self
		assert: ((data at: 'comments') collect: [ :c |
				 (c at: 'commentedEntity') at: 'name' ]) asSet
		equals: #( 'CommentedClass' 'commentedMethod' ) asSet.
	self assert: ((data at: 'comments') allSatisfy: [ :c |
			 ((c at: 'commentedEntity') at: '__typename') = 'TWithComments' ])
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

{ #category : 'tests' }
MGModelSchemaTest >> testObjectTypesAreModelConcepts [
	"The object types are exactly the concrete concepts having instances in the fixture model; the generic types are absent"

	| schema names |
	self assert: (self modelSchema isKindOf: GQLSchema).
	schema := self introspectedSchema.
	self assert: ((schema at: 'queryType') at: 'name') equals: 'Query'.
	names := (self conceptObjectTypesOf: schema) collect: [ :t |
		         t at: 'name' ].
	self
		assert: names asSet
		equals: #( 'Attribute' 'Class' 'Method' ) asSet.
	#( 'Entity' 'MetaClass' 'Model' 'Property' 'Relation' ) do: [
			:generic |
			self deny:
				((schema at: 'types') anySatisfy: [ :t | (t at: 'name') = generic ]) ]
]

{ #category : 'tests' }
MGModelSchemaTest >> testQueryFields [
	"Each root concept has a plural lowerFirst list field and a singular lowerFirst by-id field; nothing else"

	| fields |
	fields := (self introspectedSchema at: 'queryType') at: 'fields'.
	self
		assert: (fields collect: [ :f | f at: 'name' ]) asSet
		equals:
			#( 'attributes' 'attribute' 'classes' 'class' 'methods' 'method' )
				asSet.
	self assert: fields size equals: 6
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
	"Reserved names (GraphQL built-ins, Query, Number, __*) fall back to the sanitized fullName, and names are made unique and valid"

	| builder query byShortName used |
	builder := MGModelSchemaBuilder on: model.
	#( 'Query' 'String' 'Int' 'Float' 'Boolean' 'ID' 'Number' '__Type' )
		do: [ :n |
		self assert: (builder isReservedTypeName: n) description: n ].
	self deny: (builder isReservedTypeName: 'Class').
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
