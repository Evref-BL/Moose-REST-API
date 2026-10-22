"
I test MGServer in model mode over real HTTP (ZnClient): setUp starts the server with startOn:model: on the MGTestModel fixture, on the first free port of 18810..18819; tearDown always stops it.

I replay the Fluid UI requests (root type, deep __type introspection, list query, detail query) against the model concepts, and check currentModel, restart, stop, the empty model error (leaving the running server untouched) and that the generic startOn: is unchanged.
"
Class {
	#name : 'MGModelServerTest',
	#superclass : 'MGTestCase',
	#instVars : [
		'port'
	],
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'helpers' }
MGModelServerTest >> chainOf: aTypeDictionary [
	"kind/name chain of an introspected type reference, e.g. #('NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Method')"

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
MGModelServerTest >> dataOfPost: aQueryString operationName: anOperationNameOrNil variables: aDictionaryOrNil [
	"POST the request, assert no GraphQL error and answer the 'data' entry"

	| json |
	json := self
		        post: aQueryString
		        operationName: anOperationNameOrNil
		        variables: aDictionaryOrNil.
	self
		deny: (json includesKey: 'errors')
		description: [ (json at: 'errors' ifAbsent: [ nil ]) printString ].
	^ json at: 'data'
]

{ #category : 'helpers' }
MGModelServerTest >> endpoint [
	"The server binds the loopback address; use the IPv4 literal to avoid localhost resolving to ::1"

	^ 'http://127.0.0.1:' , port printString , '/graphql'
]

{ #category : 'helpers' }
MGModelServerTest >> fluidTypeDeep: aTypeName [
	"Exact deep __type introspection query sent by the Fluid client (see MGServerTest>>#fluidTypeDeep:); answer the __type object"

	^ (self
		   dataOfPost:
		   'query FluidTypeDeep($name: String!) { __type(name: $name) { kind name description fields(includeDeprecated: false) { name description args { name type { kind name ofType { kind name ofType { kind name __typename } __typename } __typename } __typename } type { kind name ofType { kind name ofType { kind name ofType { kind name __typename } __typename } __typename } __typename } __typename } __typename } }'
		   operationName: 'FluidTypeDeep'
		   variables: (Dictionary with: 'name' -> aTypeName)) at: '__type'
]

{ #category : 'helpers' }
MGModelServerTest >> modelIdOf: anEntity [
	"Opaque id of anEntity in model mode"

	^ (MGRegistry forModel: model) idOfEntity: anEntity
]

{ #category : 'helpers' }
MGModelServerTest >> post: aQueryString operationName: anOperationNameOrNil variables: aDictionaryOrNil [
	"POST a standard GraphQL JSON request; assert HTTP 200 and answer the decoded JSON response"

	| payload client response |
	payload := Dictionary new.
	payload at: 'query' put: aQueryString.
	anOperationNameOrNil ifNotNil: [ :n |
		payload at: 'operationName' put: n ].
	aDictionaryOrNil ifNotNil: [ :v | payload at: 'variables' put: v ].
	client := ZnClient new.
	response := [
		            client
			            url: self endpoint;
			            timeout: 10;
			            entity: (ZnEntity
					             with: (NeoJSONWriter toString: payload)
					             type: ZnMimeType applicationJson);
			            post.
		            client response ] ensure: [ client close ].
	self assert: response code equals: 200.
	^ NeoJSONReader fromString: response contents
]

{ #category : 'running' }
MGModelServerTest >> setUp [
	"Install the fixture model, then start the server in model mode on the first free port of 18810..18819"

	super setUp.
	port := (18810 to: 18819)
		        detect: [ :each |
				        [
					        MGServer startOn: each model: model.
					        MGServer isRunning ]
					        on: Error
					        do: [ :e |
							        MGServer stop.
							        e return: false ] ]
		        ifNone: [ nil ].
	self assert: port notNil description: 'No free port in 18810..18819'
]

{ #category : 'running' }
MGModelServerTest >> tearDown [

	[ MGServer stop ]
		on: Error
		do: [ :e | e return: nil ].
	super tearDown
]

{ #category : 'tests' }
MGModelServerTest >> testEmptyModelLeavesRunningServerUntouched [
	"startOn:model: on an empty model signals MGEmptyModelError before stopping anything: the running model-mode server keeps serving the same model on the same port"

	| running empty data |
	running := MGServer current.
	empty := FamixTest1Model new name: 'MGTestEmpty'.
	self
		should: [ MGServer startOn: port model: empty ]
		raise: MGEmptyModelError.
	self assert: MGServer current identicalTo: running.
	self assert: MGServer isRunning.
	self assert: MGServer current port equals: port.
	self assert: MGServer currentModel identicalTo: model.
	data := self
		        dataOfPost: '{ classes { name } }'
		        operationName: nil
		        variables: nil.
	self assert: (data at: 'classes') size equals: 2.
	"same with a generic server running"
	MGServer startOn: port.
	running := MGServer current.
	self
		should: [ MGServer startOn: port model: empty ]
		raise: MGEmptyModelError.
	self assert: MGServer current identicalTo: running.
	self assert: MGServer isRunning.
	self assert: MGServer currentModel isNil
]

{ #category : 'tests' }
MGModelServerTest >> testFluidGetListQuery [
	"(3) List query sent with GET, query and variables URL-encoded, on a concept list field"

	| url client response json methods |
	url := self endpoint asZnUrl.
	url
		queryAt: 'query'
		put:
			'query FluidAuto_Method($take: Int) { methods(take: $take) { id name type __typename } }';
		queryAt: 'operationName' put: 'FluidAuto_Method';
		queryAt: 'variables' put: '{"take":100}'.
	client := ZnClient new.
	[
		client
			url: url;
			timeout: 10;
			get.
		response := client response ] ensure: [ client close ].
	self assert: response code equals: 200.
	json := NeoJSONReader fromString: response contents.
	self
		deny: (json includesKey: 'errors')
		description: [ (json at: 'errors' ifAbsent: [ nil ]) printString ].
	methods := (json at: 'data') at: 'methods'.
	self assert: methods size equals: 3.
	self
		assert: (methods collect: [ :m | m at: 'name' ]) asSet
		equals: #( 'm1' 'm2' 'm3' ) asSet.
	self assert: (methods allSatisfy: [ :m |
				 (m at: '__typename') = 'Method' and: [
					 (m at: 'type') = 'Method' and: [ (m at: 'id') isString ] ] ])
]

{ #category : 'tests' }
MGModelServerTest >> testFluidPostDetail [
	"(4) Detail query by id on a concept by-id field, the id being sent as a JSON string variable"

	| data class |
	data := self
		        dataOfPost:
		        'query($id: ID!) { class(id: $id) { id name type __typename numberOfMethods methods { id name __typename } attributes { name } } }'
		        operationName: nil
		        variables:
		        (Dictionary with: 'id' -> (self modelIdOf: class1)).
	class := data at: 'class'.
	self assert: (class at: 'id') equals: (self modelIdOf: class1).
	self assert: (class at: 'name') equals: 'Class1'.
	self assert: (class at: 'type') equals: 'Class'.
	self assert: (class at: '__typename') equals: 'Class'.
	self assert: (class at: 'numberOfMethods') equals: 2.
	self
		assert: ((class at: 'methods') collect: [ :m | m at: 'name' ]) asSet
		equals: #( 'm1' 'm2' ) asSet.
	self assert: ((class at: 'methods') allSatisfy: [ :m |
			 (m at: '__typename') = 'Method' ]).
	"an id of another concept answers null"
	data := self
		        dataOfPost: 'query($id: ID!) { class(id: $id) { id } }'
		        operationName: nil
		        variables: (Dictionary with: 'id' -> (self modelIdOf: m1)).
	self assert: (data at: 'class') isNil
]

{ #category : 'tests' }
MGModelServerTest >> testFluidRootTypeAndQueryFields [
	"(1) The client asks for the root query type name; (2) the Query type exposes the root fields of the model concepts"

	| data query fields classes byId |
	data := self
		        dataOfPost:
		        'query FluidRootType { __schema { queryType { name __typename } __typename } }'
		        operationName: 'FluidRootType'
		        variables: nil.
	self
		assert: (((data at: '__schema') at: 'queryType') at: 'name')
		equals: 'Query'.
	query := self fluidTypeDeep: 'Query'.
	fields := query at: 'fields'.
	self
		assert: (fields collect: [ :f | f at: 'name' ]) asSet
		equals:
			#( 'attributes' 'attribute' 'classes' 'class' 'methods' 'method' )
				asSet.
	classes := fields detect: [ :f | (f at: 'name') = 'classes' ].
	self
		assert: (self chainOf: (classes at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Class' ).
	self
		assert: (self chainOf:
				 (((classes at: 'args') detect: [ :a | (a at: 'name') = 'take' ])
					  at: 'type'))
		equals: #( 'SCALAR' 'Int' ).
	byId := fields detect: [ :f | (f at: 'name') = 'class' ].
	self
		assert: (self chainOf: (byId at: 'type'))
		equals: #( 'OBJECT' 'Class' ).
	self
		assert: (self chainOf:
				 (((byId at: 'args') detect: [ :a | (a at: 'name') = 'id' ]) at:
					  'type'))
		equals: #( 'NON_NULL' 'SCALAR' 'ID' )
]

{ #category : 'tests' }
MGModelServerTest >> testFluidTypeDeepClass [
	"(2) Deep introspection of the Class concept: identity fields, typed relations, and no generic Entity type"

	| type byName |
	type := self fluidTypeDeep: 'Class'.
	self assert: (type at: 'kind') equals: 'OBJECT'.
	self assert: (type at: 'name') equals: 'Class'.
	self assert:
		((type at: 'description') includesSubstring: 'Moose concept').
	byName := Dictionary new.
	(type at: 'fields') do: [ :f | byName at: (f at: 'name') put: f ].
	self
		assert: (self chainOf: ((byName at: 'id') at: 'type'))
		equals: #( 'NON_NULL' 'SCALAR' 'ID' ).
	self
		assert: (self chainOf: ((byName at: 'name') at: 'type'))
		equals: #( 'SCALAR' 'String' ).
	self
		assert: (self chainOf: ((byName at: 'type') at: 'type'))
		equals: #( 'SCALAR' 'String' ).
	self
		assert: (self chainOf: ((byName at: 'methods') at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Method' ).
	self
		assert: (self chainOf: ((byName at: 'numberOfMethods') at: 'type'))
		equals: #( 'SCALAR' 'Number' ).
	self assert: (self fluidTypeDeep: 'Entity') isNil
]

{ #category : 'tests' }
MGModelServerTest >> testGenericStartOnIsUnchanged [
	"startOn: replaces the model-mode server with the generic schema (models, entities, ... and Entity type) and clears currentModel; restart then stays generic"

	| data |
	MGServer startOn: port.
	self assert: MGServer isRunning.
	self assert: MGServer current port equals: port.
	self assert: MGServer currentModel isNil.
	data := self
		        dataOfPost:
		        '{ __schema { queryType { fields { name } } } entities(take: 1) { __typename } }'
		        operationName: nil
		        variables: nil.
	self
		assert:
			((((data at: '__schema') at: 'queryType') at: 'fields') collect: [
				 :f | f at: 'name' ]) asSet
		equals:
			#( 'models' 'model' 'entities' 'entity' 'metaClass' 'relation'
			   'property' 'rootEntities' ) asSet.
	self assert: ((data at: 'entities') allSatisfy: [ :e |
			 (e at: '__typename') = 'Entity' ]).
	MGServer restart.
	self assert: MGServer currentModel isNil.
	self assert: MGServer current port equals: port.
	self assert: ((self
			  dataOfPost: '{ __type(name: "Entity") { name } }'
			  operationName: nil
			  variables: nil) at: '__type') notNil
]

{ #category : 'tests' }
MGModelServerTest >> testRestartKeepsPortAndModel [
	"restart rebuilds the schema on the same port and keeps model mode: entities added since the start become visible"

	| first data |
	first := MGServer current.
	MGServer restart.
	self assert: MGServer isRunning.
	self deny: MGServer current identicalTo: first.
	self deny: first isRunning.
	self assert: MGServer current port equals: port.
	self assert: MGServer currentModel identicalTo: model.
	data := self
		        dataOfPost: '{ classes { name } }'
		        operationName: nil
		        variables: nil.
	self assert: (data at: 'classes') size equals: 2.
	"a new concept added to the model is exposed after restart only"
	model add: (FamixTest1Comment new
			 commentedEntity: class1;
			 yourself).
	self assert:
		((self post: '{ comments { id } }' operationName: nil variables: nil)
			 includesKey: 'errors').
	MGServer restart.
	self assert: MGServer current port equals: port.
	self assert: MGServer currentModel identicalTo: model.
	data := self
		        dataOfPost: '{ comments { id } classes { name } }'
		        operationName: nil
		        variables: nil.
	self assert: (data at: 'comments') size equals: 1.
	self assert: (data at: 'classes') size equals: 2
]

{ #category : 'tests' }
MGModelServerTest >> testServerIsRunningOnModel [
	"startOn:model: runs the server on the requested port and records the served model"

	self assert: MGServer isRunning.
	self assert: MGServer current notNil.
	self assert: MGServer current port equals: port.
	self assert: MGServer currentModel identicalTo: model
]

{ #category : 'tests' }
MGModelServerTest >> testStopClearsCurrentModel [
	"stop shuts the server down (idempotently) and clears currentModel"

	self assert: MGServer currentModel identicalTo: model.
	MGServer stop.
	self deny: MGServer isRunning.
	self assert: MGServer current isNil.
	self assert: MGServer currentModel isNil.
	self shouldnt: [ MGServer stop ] raise: Error.
	self assert: MGServer currentModel isNil
]
