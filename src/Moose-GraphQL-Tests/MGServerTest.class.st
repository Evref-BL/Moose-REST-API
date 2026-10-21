"
End-to-end tests of MGServer over HTTP (ZnClient on the loopback interface), following the ""fluid"" client contract: root type introspection, deep __type introspection with variables, GET list query with URL-encoded variables, POST detail query, CORS preflight and malformed bodies.
The server is started on the first free port in 18800..18809 and always stopped in tearDown.
"
Class {
	#name : 'MGServerTest',
	#superclass : 'MGTestCase',
	#instVars : [
		'port'
	],
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'helpers' }
MGServerTest >> chainOf: aTypeDictionary [
	"kind/name chain of an introspected type reference, e.g. #('NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Model')"

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
MGServerTest >> endpoint [
	"The server binds the loopback address; use the IPv4 literal to avoid localhost resolving to ::1"

	^ 'http://127.0.0.1:' , port printString , '/graphql'
]

{ #category : 'helpers' }
MGServerTest >> fluidTypeDeep: aTypeName [
	"(2) Exact deep __type introspection query sent by the client; answer the __type object (asserting no errors)"

	| json |
	json := self
		        post:
		        'query FluidTypeDeep($name: String!) { __type(name: $name) { kind name description fields(includeDeprecated: false) { name description args { name type { kind name ofType { kind name ofType { kind name __typename } __typename } __typename } __typename } type { kind name ofType { kind name ofType { kind name ofType { kind name __typename } __typename } __typename } __typename } __typename } __typename } }'
		        operationName: 'FluidTypeDeep'
		        variables: (Dictionary with: 'name' -> aTypeName).
	self
		deny: (json includesKey: 'errors')
		description: [ (json at: 'errors' ifAbsent: [ nil ]) printString ].
	^ (json at: 'data') at: '__type'
]

{ #category : 'helpers' }
MGServerTest >> post: aQueryString operationName: anOperationNameOrNil variables: aDictionaryOrNil [
	"POST a standard GraphQL JSON request; assert HTTP 200 and answer the decoded JSON response"

	| payload response |
	payload := Dictionary new.
	payload at: 'query' put: aQueryString.
	anOperationNameOrNil ifNotNil: [ :n |
		payload at: 'operationName' put: n ].
	aDictionaryOrNil ifNotNil: [ :v | payload at: 'variables' put: v ].
	response := self postBody: (NeoJSONWriter toString: payload).
	self assert: response code equals: 200.
	^ NeoJSONReader fromString: response contents
]

{ #category : 'helpers' }
MGServerTest >> postBody: aString [
	"POST aString as application/json; answer the ZnResponse"

	| client |
	client := ZnClient new.
	^ [
		  client
			  url: self endpoint;
			  timeout: 10;
			  entity: (ZnEntity with: aString type: ZnMimeType applicationJson);
			  post.
		  client response ] ensure: [ client close ]
]

{ #category : 'running' }
MGServerTest >> setUp [
	"Install the fixture model, then start the server on the first free port of 18800..18809"

	super setUp.
	port := (18800 to: 18809)
		        detect: [ :each |
				        [
					        MGServer startOn: each.
					        MGServer isRunning ]
					        on: Error
					        do: [ :e |
							        MGServer stop.
							        e return: false ] ]
		        ifNone: [ nil ].
	self assert: port notNil description: 'No free port in 18800..18809'
]

{ #category : 'running' }
MGServerTest >> tearDown [

	[ MGServer stop ]
		on: Error
		do: [ :e | e return: nil ].
	super tearDown
]

{ #category : 'tests - fluid contract' }
MGServerTest >> testFluidGetListQuery [
	"(3) List query sent with GET, query and variables URL-encoded"

	| url client response json entities |
	url := self endpoint asZnUrl.
	url
		queryAt: 'query'
		put:
			'query FluidAuto_Entity($take: Int) { entities(take: $take) { id name type __typename } }';
		queryAt: 'operationName' put: 'FluidAuto_Entity';
		queryAt: 'variables' put: '{"take":100}'.
	client := ZnClient new.
	[
		client
			url: url;
			timeout: 10;
			get.
		response := client response ] ensure: [ client close ].
	self assert: response code equals: 200.
	self
		assert: (response headers at: 'Access-Control-Allow-Origin')
		equals: '*'.
	json := NeoJSONReader fromString: response contents.
	self
		deny: (json includesKey: 'errors')
		description: [ (json at: 'errors' ifAbsent: [ nil ]) printString ].
	entities := (json at: 'data') at: 'entities'.
	self assert: entities isArray.
	self assert: entities notEmpty.
	self assert: entities size <= 100.
	self assert: (entities allSatisfy: [ :e |
			 (e at: '__typename') = 'Entity' and: [ (e at: 'id') isString ] ])
]

{ #category : 'tests - fluid contract' }
MGServerTest >> testFluidPostDetail [
	"(4) Detail query by id, the id being sent as a JSON string variable"

	| json entity methods |
	json := self
		        post:
		        'query($id: ID!) { entity(id: $id) { id name type properties { name value __typename } relations { id name size targets { id name __typename } __typename } __typename } }'
		        operationName: nil
		        variables: (Dictionary with: 'id' -> (self idOf: class1)).
	self
		deny: (json includesKey: 'errors')
		description: [ (json at: 'errors' ifAbsent: [ nil ]) printString ].
	entity := (json at: 'data') at: 'entity'.
	self assert: (entity at: 'id') equals: (self idOf: class1).
	self assert: (entity at: 'name') equals: 'Class1'.
	self assert: (entity at: '__typename') equals: 'Entity'.
	self assert: ((entity at: 'properties') allSatisfy: [ :p |
			 (p at: '__typename') = 'Property' ]).
	methods := (entity at: 'relations') detect: [ :r |
		           (r at: 'name') = 'methods' ].
	self assert: (methods at: '__typename') equals: 'Relation'.
	self assert: (methods at: 'size') equals: 2.
	self
		assert:
		((methods at: 'targets') collect: [ :t | t at: 'name' ]) asSet
		equals: #( 'm1' 'm2' ) asSet
]

{ #category : 'tests - fluid contract' }
MGServerTest >> testFluidRootType [
	"(1) The client first asks for the root query type name"

	| json schema |
	json := self
		        post:
		        'query FluidRootType { __schema { queryType { name __typename } __typename } }'
		        operationName: 'FluidRootType'
		        variables: nil.
	self deny: (json includesKey: 'errors').
	schema := (json at: 'data') at: '__schema'.
	self assert: ((schema at: 'queryType') at: 'name') equals: 'Query'.
	self
		assert: ((schema at: 'queryType') at: '__typename')
		equals: '__Type'.
	self assert: (schema at: '__typename') equals: '__Schema'
]

{ #category : 'tests - fluid contract' }
MGServerTest >> testFluidTypeDeepEntity [
	"(2) Deep introspection of Entity: id is ID!, name is String, properties is [Property!]!"

	| type byName |
	type := self fluidTypeDeep: 'Entity'.
	self assert: (type at: 'kind') equals: 'OBJECT'.
	self assert: (type at: 'name') equals: 'Entity'.
	byName := Dictionary new.
	(type at: 'fields') do: [ :f | byName at: (f at: 'name') put: f ].
	self
		assert: byName keys asSet
		equals:
			#( 'id' 'name' 'mooseName' 'type' 'model' 'metaClass' 'properties'
			   'relations' 'related' ) asSet.
	self
		assert: (self chainOf: ((byName at: 'id') at: 'type'))
		equals: #( 'NON_NULL' 'SCALAR' 'ID' ).
	self
		assert: (self chainOf: ((byName at: 'name') at: 'type'))
		equals: #( 'SCALAR' 'String' ).
	self
		assert: (self chainOf: ((byName at: 'properties') at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Property' ).
	self
		assert: (self chainOf: ((byName at: 'related') at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Entity' )
]

{ #category : 'tests - fluid contract' }
MGServerTest >> testFluidTypeDeepQuery [
	"(2) Deep introspection of Query: models is [Model!]! with an optional take: Int, entity takes id: ID!"

	| type fields models entity |
	type := self fluidTypeDeep: 'Query'.
	self assert: (type at: 'kind') equals: 'OBJECT'.
	self assert: (type at: 'name') equals: 'Query'.
	self assert: (type at: '__typename') equals: '__Type'.
	fields := type at: 'fields'.
	models := fields detect: [ :f | (f at: 'name') = 'models' ].
	self
		assert: (self chainOf: (models at: 'type'))
		equals: #( 'NON_NULL' 'LIST' 'NON_NULL' 'OBJECT' 'Model' ).
	self assert: (models at: '__typename') equals: '__Field'.
	self
		assert: (self chainOf:
				 (((models at: 'args') detect: [ :a | (a at: 'name') = 'take' ])
					  at: 'type'))
		equals: #( 'SCALAR' 'Int' ).
	entity := fields detect: [ :f | (f at: 'name') = 'entity' ].
	self
		assert: (self chainOf: (entity at: 'type'))
		equals: #( 'OBJECT' 'Entity' ).
	self
		assert: (self chainOf:
				 (((entity at: 'args') detect: [ :a | (a at: 'name') = 'id' ])
					  at: 'type'))
		equals: #( 'NON_NULL' 'SCALAR' 'ID' )
]

{ #category : 'tests - http' }
MGServerTest >> testMalformedBody [
	"(6) A body that is not JSON, or JSON without a usable query, answers 200 with a GraphQL 'errors' entry"

	#( '{not json' '[1, 2]' '"just a string"' '{"query": "{ nope "}'
	   '{"query": "{ models { id } }", "variables": "[1]"}' ) do: [ :body |
			| response json |
			response := self postBody: body.
			self assert: response code equals: 200.
			json := NeoJSONReader fromString: response contents.
			self assert: (json includesKey: 'errors') description: body.
			self assert: (json at: 'errors') notEmpty.
			self assert: ((json at: 'errors') first at: 'message') isString ].
	"the server keeps serving after bad requests"
	self assert: MGServer isRunning
]

{ #category : 'tests - http' }
MGServerTest >> testOptionsPreflight [
	"(5) CORS preflight answers 204 with permissive CORS headers"

	| client response |
	client := ZnClient new.
	[
		client
			url: self endpoint;
			timeout: 10;
			method: #OPTIONS;
			execute.
		response := client response ] ensure: [ client close ].
	self assert: response code equals: 204.
	self
		assert: (response headers at: 'Access-Control-Allow-Origin')
		equals: '*'
]

{ #category : 'tests' }
MGServerTest >> testServerIsRunning [

	self assert: MGServer isRunning.
	self assert: MGServer current notNil.
	self assert: MGServer current port equals: port.
	self assert: MGServer defaultPort equals: 4000
]

{ #category : 'tests - http' }
MGServerTest >> testStopAndRestart [
	"stop shuts the server down (idempotently); startOn: restarts it, replacing any running instance"

	| first |
	first := MGServer current.
	MGServer stop.
	self deny: MGServer isRunning.
	self assert: MGServer current isNil.
	self deny: first isRunning.
	self shouldnt: [ MGServer stop ] raise: Error.
	MGServer startOn: port.
	self assert: MGServer isRunning.
	MGServer startOn: port.
	self assert: MGServer isRunning.
	MGServer stop.
	self deny: MGServer isRunning
]
