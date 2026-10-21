"
Real HTTP round-trips against a GQLHttpServer bound to the loopback interface on a free port (first free in 18790-18799; tests are skipped when none is available). The server is always stopped in #tearDown.
"
Class {
	#name : 'GQLHttpServerTest',
	#superclass : 'TestCase',
	#instVars : [
		'server'
	],
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'running' }
GQLHttpServerTest >> newSchema [

	| b |
	b := GQLSchemaBuilder new.
	b object: 'Query' fields: [ :o |
			o field: 'hello' type: 'String' resolve: [ 'world' ].
			o
				field: 'greet'
				type: 'String'
				args: { ('name' -> 'String!') }
				resolve: [ :src :args | 'Hello, ' , (args at: 'name') ].
			o field: 'ctx' type: 'String' resolve: [ :src :args :ctx | ctx ] ].
	b query: 'Query'.
	^ b build
]

{ #category : 'running' }
GQLHttpServerTest >> setUp [
	"Start a server on the first free port of 18790-18799; skip the test when none is free"

	| schema |
	super setUp.
	schema := self newSchema.
	18790 to: 18799 do: [ :port |
			| candidate |
			candidate := GQLHttpServer on: port schema: schema.
			[ candidate start ]
				on: Error
				do: [ :e | "port unusable, try the next one" ].
			candidate isRunning
				ifTrue: [
						server := candidate.
						^ self ]
				ifFalse: [ candidate stop ] ].
	self skip: 'No free port in 18790-18799'
]

{ #category : 'running' }
GQLHttpServerTest >> tearDown [

	server ifNotNil: [ server stop ].
	super tearDown
]

{ #category : 'tests' }
GQLHttpServerTest >> testBindsLoopbackOnly [

	| zn |
	zn := server instVarNamed: 'server'.
	self
		assert: zn bindingAddress
		equals: NetNameResolver loopBackAddress.
	self assert: zn port equals: server port
]

{ #category : 'tests' }
GQLHttpServerTest >> testContextBlockOverHttp [

	| client body |
	server contextBlock: [ :request |
		request headers at: 'X-Token' ifAbsent: [ 'none' ] ].
	client := ZnClient new.
	[
		body := client
			        url: server url;
			        headerAt: 'X-Token' put: 'secret';
			        entity: (ZnEntity json: '{"query":"{ ctx }"}');
			        post ] ensure: [ client close ].
	self
		assert: (((NeoJSONReader fromString: body) at: 'data') at: 'ctx')
		equals: 'secret'
]

{ #category : 'tests' }
GQLHttpServerTest >> testGetRoundTrip [

	| client body |
	client := ZnClient new.
	[
		body := client
			        url: server url;
			        queryAt: 'query' put: '{ hello }';
			        get.
		self assert: client response code equals: 200 ] ensure: [
		client close ].
	self
		assert: (NeoJSONReader fromString: body)
		equals: (Dictionary new
				 at: 'data' put: (Dictionary new
						  at: 'hello' put: 'world';
						  yourself);
				 yourself)
]

{ #category : 'tests' }
GQLHttpServerTest >> testOptionsPreflightRoundTrip [

	| client response |
	client := ZnClient new.
	[
		client
			url: server url;
			method: #OPTIONS;
			execute.
		response := client response ] ensure: [ client close ].
	self assert: response code equals: 204.
	self
		assert: (response headers at: 'Access-Control-Allow-Origin')
		equals: '*'.
	self
		assert: (response headers at: 'Access-Control-Allow-Methods')
		equals: 'GET, POST, OPTIONS'.
	self
		assert: (response headers at: 'Access-Control-Allow-Headers')
		equals: 'content-type, accept'.
	self
		assert: (response headers at: 'Access-Control-Max-Age')
		equals: '86400'
]

{ #category : 'tests' }
GQLHttpServerTest >> testPostJsonRoundTrip [

	| client body |
	self assert: server isRunning.
	self
		assert: server url
		equals: 'http://localhost:' , server port printString , '/graphql'.
	client := ZnClient new.
	[
		body := client
			        url: server url;
			        entity: (ZnEntity json:
						         '{"query":"query($n: String!) { greet(name: $n) }","variables":{"n":"net"}}');
			        post.
		self assert: client response code equals: 200.
		self assert: client response contentType main equals: 'application'.
		self assert: client response contentType sub equals: 'json'.
		self
			assert: (client response headers at: 'Access-Control-Allow-Origin')
			equals: '*' ] ensure: [ client close ].
	self
		assert: (((NeoJSONReader fromString: body) at: 'data') at: 'greet')
		equals: 'Hello, net'
]

{ #category : 'tests' }
GQLHttpServerTest >> testStop [

	self assert: server isRunning.
	server stop.
	self deny: server isRunning.
	"stopping twice is harmless"
	server stop.
	self deny: server isRunning.
	"a fresh server is not running before start"
	self deny:
		(GQLHttpServer on: server port schema: self newSchema) isRunning
]
