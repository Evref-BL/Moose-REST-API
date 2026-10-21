"
Tests executing GraphQL queries against MGSchema default over the MGTestModel fixture: entry points, id lookups with variables, take limits, a full sweep over every entity, and schema conventions checked via introspection.
"
Class {
	#name : 'MGSchemaTest',
	#superclass : 'MGTestCase',
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'helpers' }
MGSchemaTest >> kindsOf: aTypeDictionary [
	"Answer the chain of kinds of an introspected type reference, ending with the named type, e.g. #('NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Model')"

	| result current |
	result := OrderedCollection new.
	current := aTypeDictionary.
	[ current notNil ] whileTrue: [
			result add: (current at: 'kind').
			(current at: 'name') ifNotNil: [ :n | result add: n ].
			current := current at: 'ofType' ifAbsent: [ nil ] ].
	^ result asArray
]

{ #category : 'tests' }
MGSchemaTest >> testBuildAndDefault [
	"build answers a fresh GQLSchema; default is cached until reset"

	| first |
	self assert: (MGSchema build isKindOf: GQLSchema).
	first := MGSchema default.
	self assert: MGSchema default identicalTo: first.
	MGSchema reset.
	self deny: MGSchema default identicalTo: first.
	self assert: (MGSchema default isKindOf: GQLSchema).
	self assert: MGSchema defaultTake equals: 100.
	self assert: MGSchema maxTake equals: 1000.
	self
		assert: (MGSchema registryFrom: self registry)
		identicalTo: self registry.
	self assert: ((MGSchema registryFrom: nil) isKindOf: MGRegistry)
]

{ #category : 'tests' }
MGSchemaTest >> testEntitiesOfModelAndType [

	| entities |
	entities := (self
		             dataOf:
		             'query($m: ID) { entities(modelId: $m, type: "Method") { id name type mooseName } }'
		             variables: (Dictionary with: 'm' -> self modelId)) at:
		            'entities'.
	self assert: entities size equals: 3.
	self assert:
		(entities allSatisfy: [ :e | (e at: 'type') = 'Method' ]).
	self
		assert: (entities collect: [ :e | e at: 'name' ]) asSet
		equals: #( 'm1' 'm2' 'm3' ) asSet.
	self assert: (entities allSatisfy: [ :e |
			 (e at: 'id') beginsWith: self modelId , ':' ]).
	self assert:
		((entities collect: [ :e | e at: 'mooseName' ]) includes:
			 'Class1.m1').
	"unknown model id -> empty list, not an error"
	self assert:
		((self dataOf: '{ entities(modelId: "nope") { id } }') at:
			 'entities') isEmpty
]

{ #category : 'tests' }
MGSchemaTest >> testEntityDetailWithVariables [
	"entity(id: $id) exposes sorted properties and relations; Class1.methods has 2 targets m1 and m2"

	| entity properties relations methods |
	entity := (self
		           dataOf:
		           'query Detail($id: ID!) { entity(id: $id) { id name type model { name } metaClass { name } properties { id name type value isDerived } relations { id name size isMultivalued targets { id name } } } }'
		           variables: (Dictionary with: 'id' -> (self idOf: class1)))
		          at: 'entity'.
	self assert: (entity at: 'id') equals: (self idOf: class1).
	self assert: (entity at: 'name') equals: 'Class1'.
	self assert: (entity at: 'type') equals: 'Class'.
	self assert: ((entity at: 'model') at: 'name') equals: 'MGTestModel'.
	self assert: ((entity at: 'metaClass') at: 'name') equals: 'Class'.
	properties := entity at: 'properties'.
	self
		assert:
		((properties detect: [ :p | (p at: 'name') = 'name' ]) at: 'value')
		equals: 'Class1'.
	self
		assert:
		((properties detect: [ :p | (p at: 'name') = 'name' ]) at: 'id')
		equals: (self idOf: class1) , '/name'.
	relations := entity at: 'relations'.
	methods := relations detect: [ :r | (r at: 'name') = 'methods' ].
	self assert: (methods at: 'size') equals: 2.
	self assert: (methods at: 'isMultivalued').
	self
		assert:
		((methods at: 'targets') collect: [ :t | t at: 'name' ]) asSet
		equals: #( 'm1' 'm2' ) asSet.
	self
		assert: ((methods at: 'targets') collect: [ :t | t at: 'id' ]) asSet
		equals: {
				(self idOf: m1).
				(self idOf: m2) } asSet
]

{ #category : 'tests' }
MGSchemaTest >> testMetaClassById [

	| metaClass |
	metaClass := (self
		              dataOf:
		              'query($id: ID!) { metaClass(id: $id) { id name fullName superclass { name } count instances { name } first: instances(take: 1) { name } } }'
		              variables:
		              (Dictionary with: 'id' -> (self modelId , ':Method')))
		             at: 'metaClass'.
	self assert: (metaClass at: 'name') equals: 'Method'.
	self assert: (metaClass at: 'count') equals: 3.
	self
		assert: (metaClass at: 'id')
		equals: self modelId , ':' , (metaClass at: 'fullName').
	self assert: ((metaClass at: 'superclass') at: 'name') isString.
	self
		assert:
		((metaClass at: 'instances') collect: [ :i | i at: 'name' ]) asSet
		equals: #( 'm1' 'm2' 'm3' ) asSet.
	self assert: (metaClass at: 'first') size equals: 1
]

{ #category : 'tests' }
MGSchemaTest >> testModelByIdAndName [

	| byId byName |
	byId := (self
		         dataOf:
		         'query($id: ID!) { model(id: $id) { id name entities(take: 2) { id } all: entities { id } methods: entities(type: "Method") { name } } }'
		         variables: (Dictionary with: 'id' -> self modelId)) at:
		        'model'.
	self assert: (byId at: 'name') equals: 'MGTestModel'.
	self assert: (byId at: 'entities') size equals: 2.
	self assert: (byId at: 'all') size equals: 6.
	self
		assert: ((byId at: 'methods') collect: [ :e | e at: 'name' ]) asSet
		equals: #( 'm1' 'm2' 'm3' ) asSet.
	byName := (self dataOf: '{ model(id: "MGTestModel") { id } }') at:
		          'model'.
	self assert: (byName at: 'id') equals: self modelId
]

{ #category : 'tests' }
MGSchemaTest >> testModelEntityTypesAndTypename [

	| data types |
	data := self
		        dataOf:
		        'query($id: ID!) { __typename model(id: $id) { __typename entityTypes { __typename id name count } one: entityTypes(take: 1) { name } } }'
		        variables: (Dictionary with: 'id' -> self modelId).
	self assert: (data at: '__typename') equals: 'Query'.
	self assert: ((data at: 'model') at: '__typename') equals: 'Model'.
	types := (data at: 'model') at: 'entityTypes'.
	self
		assert: (types collect: [ :t | t at: 'name' ]) asArray
		equals: #( 'Attribute' 'Class' 'Method' ).
	self
		assert: (types collect: [ :t | t at: 'count' ]) asArray
		equals: #( 1 2 3 ).
	self assert:
		(types allSatisfy: [ :t | (t at: '__typename') = 'MetaClass' ]).
	self assert: ((data at: 'model') at: 'one') size equals: 1
]

{ #category : 'tests' }
MGSchemaTest >> testModels [

	| models mine |
	models := (self dataOf: '{ models { id name size metamodelName } }')
		          at: 'models'.
	mine := models
		        detect: [ :m | (m at: 'name') = 'MGTestModel' ]
		        ifNone: [ nil ].
	self assert: mine notNil.
	self assert: (mine at: 'id') equals: self modelId.
	self assert: (mine at: 'size') equals: 6.
	self assert: (mine at: 'metamodelName') equals: 'FamixTest1Model'
]

{ #category : 'tests' }
MGSchemaTest >> testRelationAndPropertyById [

	| relation property |
	relation := (self
		             dataOf:
		             'query($id: ID!) { relation(id: $id) { id name type size isDerived isContainer target { name } targets { name } owner { name } } }'
		             variables:
		             (Dictionary with:
			              'id' -> ((self idOf: class1) , '/methods'))) at:
		            'relation'.
	self
		assert: (relation at: 'id')
		equals: (self idOf: class1) , '/methods'.
	self assert: (relation at: 'name') equals: 'methods'.
	self assert: (relation at: 'size') equals: 2.
	self assert: ((relation at: 'owner') at: 'name') equals: 'Class1'.
	self
		assert:
		((relation at: 'targets') collect: [ :t | t at: 'name' ]) asSet
		equals: #( 'm1' 'm2' ) asSet.
	"The declared FM3 type of Famix 'methods' is the trait TMethod"
	self assert: (relation at: 'type') equals: 'TMethod'.
	self deny: (relation at: 'isContainer').
	property := (self
		             dataOf:
		             'query($id: ID!) { property(id: $id) { id name value owner { name } } }'
		             variables:
		             (Dictionary with: 'id' -> ((self idOf: m3) , '/name')))
		            at: 'property'.
	self assert: (property at: 'name') equals: 'name'.
	self assert: (property at: 'value') equals: 'm3'.
	self assert: ((property at: 'owner') at: 'name') equals: 'm3'
]

{ #category : 'tests' }
MGSchemaTest >> testSchemaConventions [
	"Introspection-level contract relied upon by generic GraphQL clients:
	- Query list fields unwrap to a LIST of OBJECT and accept an optional take: Int
	- Query by-id fields take a mandatory id: ID!
	- every Moose object type has id: ID! and name: String
	- no leftover demo types (Account, Transaction)"

	| schema fields types objectTypes typeRef |
	typeRef := 'type { kind name ofType { kind name ofType { kind name ofType { kind name } } } }'.
	schema := (self dataOf:
		           '{ __schema { queryType { name fields { name args { name '
		           , typeRef , ' } ' , typeRef
		           , ' } } types { kind name fields { name ' , typeRef
		           , ' } } } }') at: '__schema'.
	self assert: ((schema at: 'queryType') at: 'name') equals: 'Query'.
	fields := (schema at: 'queryType') at: 'fields'.
	self
		assert: (fields collect: [ :f | f at: 'name' ]) asSet
		equals:
			#( 'models' 'model' 'entities' 'entity' 'metaClass' 'relation'
			   'property' ) asSet.
	fields do: [ :f |
			| kinds take idArg |
			kinds := (self kindsOf: (f at: 'type')) reject: [ :k |
				         k = 'NON_NULL' ].
			kinds first = 'LIST'
				ifTrue: [
						self assert: kinds second equals: 'OBJECT'.
						take := (f at: 'args')
							        detect: [ :a | (a at: 'name') = 'take' ]
							        ifNone: [ nil ].
						self
							assert: take notNil
							description: (f at: 'name') , ' has no take argument'.
						self
							assert: (self kindsOf: (take at: 'type'))
							equals: #( 'SCALAR' 'Int' ) ]
				ifFalse: [
						self assert: kinds first equals: 'OBJECT'.
						idArg := (f at: 'args')
							         detect: [ :a | (a at: 'name') = 'id' ]
							         ifNone: [ nil ].
						self
							assert: idArg notNil
							description: (f at: 'name') , ' has no id argument'.
						self
							assert: (self kindsOf: (idArg at: 'type'))
							equals: #( 'NON_NULL' 'SCALAR' 'ID' ) ] ].
	types := schema at: 'types'.
	self deny: (types anySatisfy: [ :t |
			 #( 'Account' 'Transaction' ) includes: (t at: 'name') ]).
	objectTypes := types select: [ :t |
			               (t at: 'kind') = 'OBJECT' and: [
					               ((t at: 'name') beginsWith: '__') not and: [
						               (t at: 'name') ~= 'Query' ] ] ].
	self
		assert: (objectTypes collect: [ :t | t at: 'name' ]) asSet
		equals:
		#( 'Model' 'Entity' 'Property' 'Relation' 'MetaClass' ) asSet.
	objectTypes do: [ :t |
			| byName |
			byName := Dictionary new.
			(t at: 'fields') do: [ :f | byName at: (f at: 'name') put: f ].
			self
				assert: (self kindsOf: ((byName at: 'id') at: 'type'))
				equals: #( 'NON_NULL' 'SCALAR' 'ID' ).
			self
				assert: (self kindsOf: ((byName at: 'name') at: 'type'))
				equals: #( 'SCALAR' 'String' ) ]
]

{ #category : 'tests' }
MGSchemaTest >> testSweepAllEntities [
	"For every entity of the fixture model, query everything that can be computed: data must come back and no error is reported, since all values are guarded"

	| ids |
	ids := ((self
		         dataOf: 'query($m: ID) { entities(modelId: $m) { id } }'
		         variables: (Dictionary with: 'm' -> self modelId)) at:
		        'entities') collect: [ :e | e at: 'id' ].
	self assert: ids size equals: 6.
	ids do: [ :id |
			| response entity |
			self
				shouldnt: [
						response := self
							            query:
							            'query($id: ID!) { entity(id: $id) { id name mooseName type model { id } metaClass { id count } properties { id name type value isDerived owner { id } } relations { id name type isMultivalued isContainer isDerived size target { id } targets { id } owner { id } } related { id } } }'
							            variables: (Dictionary with: 'id' -> id) ]
				raise: Error.
			self
				deny: (response includesKey: 'errors')
				description: [
				id , ': ' , (response at: 'errors' ifAbsent: [ nil ]) printString ].
			entity := (response at: 'data') at: 'entity'.
			self assert: entity notNil.
			self assert: (entity at: 'id') equals: id.
			self assert: (entity at: 'properties') notEmpty.
			self assert: ((entity at: 'properties') allSatisfy: [ :p |
					 (p at: 'value') isNil or: [ (p at: 'value') isString ] ]).
			self assert: ((entity at: 'relations') allSatisfy: [ :r |
					 (r at: 'size') = (r at: 'targets') size ]) ]
]

{ #category : 'tests' }
MGSchemaTest >> testTakeLimits [
	"take bounds every list field: 0 -> empty, small -> exact, negative -> default"

	| data |
	data := self
		        dataOf:
		        'query($m: ID!, $e: ID!) { none: entities(take: 0) { id } two: entities(modelId: $m, take: 2) { id } neg: entities(modelId: $m, take: -1) { id } models(take: 1) { id } entity(id: $e) { related(take: 1) { id } allRelated: related { id } relations { targets(take: 1) { id } } } }'
		        variables: (Dictionary new
				         at: 'm' put: self modelId;
				         at: 'e' put: (self idOf: class1);
				         yourself).
	self assert: (data at: 'none') isEmpty.
	self assert: (data at: 'two') size equals: 2.
	self assert: (data at: 'neg') size equals: 6.
	self assert: (data at: 'models') size equals: 1.
	self assert: ((data at: 'entity') at: 'related') size equals: 1.
	self assert: ((data at: 'entity') at: 'allRelated') size >= 3.
	self assert:
		(((data at: 'entity') at: 'relations') allSatisfy: [ :r |
			 (r at: 'targets') size <= 1 ])
]

{ #category : 'tests' }
MGSchemaTest >> testUnknownIdsAnswerNull [
	"Unknown or malformed ids resolve to null without any GraphQL error"

	| data |
	data := self dataOf:
		        '{ model(id: "nope") { id } entity(id: "999999:1") { id } e2: entity(id: "zz") { id } metaClass(id: "1:NoSuchClass") { id } relation(id: "a/b/c") { id } property(id: "") { id } }'.
	#( 'model' 'entity' 'e2' 'metaClass' 'relation' 'property' ) do: [
			:key |
			self assert: (data includesKey: key).
			self assert: (data at: key) isNil ]
]
