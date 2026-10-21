"
Unit tests for GQLHttpHandler. No socket is opened: ZnRequests are built in memory and passed to #handleRequest:, and the JSON bodies of the ZnResponses are parsed with NeoJSONReader.

Covers GET / POST (JSON and application/graphql) / OPTIONS preflight, 404 and 405 responses, CORS headers on every response, request-level error messages and the internal error guard.
"
Class {
	#name : 'GQLHttpHandlerTest',
	#superclass : 'TestCase',
	#instVars : [
		'schema',
		'handler'
	],
	#category : 'GraphQL-Core-Tests',
	#package : 'GraphQL-Core-Tests'
}

{ #category : 'helpers' }
GQLHttpHandlerTest >> assertCorsHeaders: aResponse [

	self
		assert: (aResponse headers at: 'Access-Control-Allow-Origin')
		equals: '*'.
	self
		assert: (aResponse headers at: 'Access-Control-Allow-Methods')
		equals: 'GET, POST, OPTIONS'.
	self
		assert: (aResponse headers at: 'Access-Control-Allow-Headers')
		equals: 'content-type, accept'
]

{ #category : 'helpers' }
GQLHttpHandlerTest >> assertSingleError: aMessage in: aResponse [
	"Assert aResponse is a 200 JSON response whose only content is one error with aMessage"

	| json |
	self assert: aResponse code equals: 200.
	json := self jsonOf: aResponse.
	self deny: (json includesKey: 'data').
	self assert: (json at: 'errors') size equals: 1.
	self
		assert: ((json at: 'errors') first at: 'message')
		equals: aMessage
]

{ #category : 'helpers' }
GQLHttpHandlerTest >> graphqlEntity: aString type: aMimeTypeString [
	"Zinc treats application/graphql as binary: a ZnStringEntity silently refuses that content type, so build a byte array entity (as ZnServer does when reading such a request)"

	^ (ZnEntity bytes: aString utf8Encoded)
		  contentType: (ZnMimeType fromString: aMimeTypeString);
		  yourself
]

{ #category : 'helpers' }
GQLHttpHandlerTest >> jsonOf: aResponse [
	"Check the response is JSON with CORS headers and answer its parsed body"

	self assertCorsHeaders: aResponse.
	self assert: aResponse hasEntity.
	self
		assert: (aResponse headers at: 'Content-Type')
		equals: 'application/json;charset=utf-8'.
	^ NeoJSONReader fromString: aResponse contents
]

{ #category : 'helpers' }
GQLHttpHandlerTest >> postJson: aJsonString [

	^ handler handleRequest:
		  ((ZnRequest post: '/graphql') entity: (ZnEntity json: aJsonString))
]

{ #category : 'running' }
GQLHttpHandlerTest >> setUp [

	| b |
	super setUp.
	b := GQLSchemaBuilder new.
	b object: 'Query' fields: [ :o |
			o field: 'hello' type: 'String' resolve: [ 'world' ].
			o
				field: 'greet'
				type: 'String'
				args: { ('name' -> 'String!') }
				resolve: [ :src :args | 'Hello, ' , (args at: 'name') ].
			o field: 'boom' type: 'String' resolve: [ self error: 'boom!' ].
			o field: 'ctx' type: 'String' resolve: [ :src :args :ctx | ctx ] ].
	b query: 'Query'.
	schema := b build.
	handler := GQLHttpHandler schema: schema
]

{ #category : 'tests - routing' }
GQLHttpHandlerTest >> testAcceptedPaths [

	#( '/graphql' '/graphql/' '/' ) do: [ :each |
			| response |
			response := handler handleRequest:
				            (ZnRequest get: each , '?query=%7Bhello%7D').
			self assert: response code equals: 200.
			self
				assert: (((self jsonOf: response) at: 'data') at: 'hello')
				equals: 'world' ].
	"a custom path"
	handler path: '/api'.
	self
		assert:
			(handler handleRequest: (ZnRequest get: '/api?query=%7Bhello%7D'))
				code
		equals: 200.
	self
		assert:
			(handler handleRequest:
				 (ZnRequest get: '/graphql?query=%7Bhello%7D')) code
		equals: 404
]

{ #category : 'tests - context' }
GQLHttpHandlerTest >> testContextBlockReceivesRequest [

	| json |
	handler contextBlock: [ :request | request uri queryAt: 'token' ].
	json := self jsonOf: (handler handleRequest:
			         (ZnRequest get: '/graphql?query=%7Bctx%7D&token=abc')).
	self assert: ((json at: 'data') at: 'ctx') equals: 'abc'.
	"without a context block, the context is nil"
	handler contextBlock: nil.
	json := self jsonOf:
		        (handler handleRequest:
			         (ZnRequest get: '/graphql?query=%7Bctx%7D')).
	self assert: ((json at: 'data') at: 'ctx') isNil
]

{ #category : 'tests - routing' }
GQLHttpHandlerTest >> testCorsHeadersOnEveryResponse [

	{
		(ZnRequest get: '/graphql?query=%7Bhello%7D').
		(ZnRequest get: '/graphql').
		(ZnRequest get: '/nowhere').
		(ZnRequest put: '/graphql').
		(ZnRequest options: '/graphql').
		((ZnRequest post: '/graphql') entity:
			 (ZnEntity json: '{"query":"{ boom }"}')).
		((ZnRequest post: '/graphql') entity: (ZnEntity json: '[1]')) } do: [
		:request | self assertCorsHeaders: (handler handleRequest: request) ]
]

{ #category : 'tests - GET' }
GQLHttpHandlerTest >> testGetErrors [

	self
		assertSingleError: 'Must provide query string.'
		in: (handler handleRequest: (ZnRequest get: '/graphql')).
	self
		assertSingleError: 'Must provide query string.'
		in: (handler handleRequest: (ZnRequest get: '/graphql?query=')).
	self
		assertSingleError: 'Variables are invalid JSON.'
		in: (handler handleRequest:
				 (ZnRequest get: '/graphql?query=%7Bhello%7D&variables=%7Bbad')).
	"variables must be a JSON object"
	self
		assertSingleError: 'Variables are invalid JSON.'
		in: (handler handleRequest:
				 (ZnRequest get: '/graphql?query=%7Bhello%7D&variables=%5B1%5D'))
]

{ #category : 'tests - GET' }
GQLHttpHandlerTest >> testGetQuery [

	| response json |
	response := handler handleRequest:
		            (ZnRequest get: '/graphql?query=%7Bhello%7D').
	self assert: response code equals: 200.
	json := self jsonOf: response.
	self assert: json keys asArray equals: #( 'data' ).
	self assert: ((json at: 'data') at: 'hello') equals: 'world'
]

{ #category : 'tests - GET' }
GQLHttpHandlerTest >> testGetWithVariablesAndOperationName [

	| uri response json |
	uri := ZnUrl new
		       addPathSegment: 'graphql';
		       queryAt: 'query'
		       put:
			       'query A { hello } query B($n: String!) { greet(name: $n) }';
		       queryAt: 'operationName' put: 'B';
		       queryAt: 'variables' put: '{"n":"Ann"}';
		       yourself.
	response := handler handleRequest: (ZnRequest get: uri).
	self assert: response code equals: 200.
	json := self jsonOf: response.
	self deny: (json includesKey: 'errors').
	self assert: (json at: 'data') keys asArray equals: #( 'greet' ).
	self assert: ((json at: 'data') at: 'greet') equals: 'Hello, Ann'
]

{ #category : 'tests - context' }
GQLHttpHandlerTest >> testInternalErrorNeverRaises [
	"An unexpected failure (here in the context block) answers a JSON 'Internal server error.' with CORS headers instead of raising"

	| response json error |
	handler contextBlock: [ :request | self error: 'secret detail' ].
	response := handler handleRequest:
		            (ZnRequest get: '/graphql?query=%7Bhello%7D').
	json := self jsonOf: response.
	self deny: (json includesKey: 'data').
	error := (json at: 'errors') first.
	self assert: (error at: 'message') equals: 'Internal server error.'.
	"details are hidden unless debug is enabled"
	self deny: (error includesKey: 'extensions').
	self deny: (response contents includesSubstring: 'secret detail').
	handler debug: true.
	error := ((self jsonOf:
		           (handler handleRequest:
			            (ZnRequest get: '/graphql?query=%7Bhello%7D'))) at:
		          'errors') first.
	self assert: (error at: 'message') equals: 'Internal server error.'.
	self
		assert: ((error at: 'extensions') at: 'exception')
		equals: 'Error'.
	self assert:
		(((error at: 'extensions') at: 'description') includesSubstring:
			 'secret detail')
]

{ #category : 'tests - routing' }
GQLHttpHandlerTest >> testMethodNotAllowed [

	{
		(ZnRequest put: '/graphql').
		(ZnRequest delete: '/graphql').
		(ZnRequest head: '/graphql') } do: [ :request |
			| response |
			response := handler handleRequest: request.
			self assert: response code equals: 405.
			self
				assert: (response headers at: 'Allow')
				equals: 'GET, POST, OPTIONS'.
			self assertCorsHeaders: response ].
	self
		assert:
			(((self jsonOf:
				   (handler handleRequest: (ZnRequest put: '/graphql'))) at:
				  'errors') first at: 'message')
		equals: 'Method not allowed: PUT'
]

{ #category : 'tests - routing' }
GQLHttpHandlerTest >> testNotFound [

	| response json |
	response := handler handleRequest:
		            (ZnRequest get: '/other?query=%7Bhello%7D').
	self assert: response code equals: 404.
	json := self jsonOf: response.
	self deny: (json includesKey: 'data').
	self assert:
		(((json at: 'errors') first at: 'message') includesSubstring:
			 '/other').
	response := handler handleRequest:
		            ((ZnRequest post: '/graphql/x') entity:
			             (ZnEntity json: '{"query":"{ hello }"}')).
	self assert: response code equals: 404.
	self assertCorsHeaders: response
]

{ #category : 'tests - routing' }
GQLHttpHandlerTest >> testOptionsPreflight [

	| response |
	response := handler handleRequest: (ZnRequest options: '/graphql').
	self assert: response code equals: 204.
	self assertCorsHeaders: response.
	self
		assert: (response headers at: 'Access-Control-Max-Age')
		equals: '86400'.
	self deny: response hasEntity.
	"also built from an empty request"
	response := handler handleRequest: (ZnRequest empty
			             method: #OPTIONS;
			             url: '/graphql/';
			             yourself).
	self assert: response code equals: 204.
	self assertCorsHeaders: response
]

{ #category : 'tests - POST' }
GQLHttpHandlerTest >> testPostApplicationGraphql [
	"An application/graphql body is the query text itself"

	| response json |
	response := handler handleRequest:
		            ((ZnRequest post: '/graphql') entity:
			             (self
				              graphqlEntity: '{ hello }'
				              type: 'application/graphql')).
	self assert: response code equals: 200.
	json := self jsonOf: response.
	self assert: ((json at: 'data') at: 'hello') equals: 'world'.
	"operationName may come from the URL; content type parameters and case are ignored"
	response := handler handleRequest:
		            ((ZnRequest post: '/graphql?operationName=B') entity:
			             (self
				              graphqlEntity: 'query A { boom } query B { hello }'
				              type: 'Application/GraphQL; charset=utf-8')).
	json := self jsonOf: response.
	self deny: (json includesKey: 'errors').
	self assert: (json at: 'data') keys asArray equals: #( 'hello' )
]

{ #category : 'tests - POST' }
GQLHttpHandlerTest >> testPostBodyErrors [

	| response json |
	self
		assertSingleError: 'Must provide query string.'
		in: (handler handleRequest: (ZnRequest post: '/graphql')).
	self
		assertSingleError: 'Must provide query string.'
		in: (self postJson: '{}').
	self
		assertSingleError: 'Must provide query string.'
		in: (self postJson: '{"query":""}').
	self
		assertSingleError: 'Must provide query string.'
		in: (self postJson: '{"query":42}').
	self
		assertSingleError: 'Batched queries are not supported.'
		in: (self postJson: '[{"query":"{ hello }"}]').
	self
		assertSingleError: 'Body must be a JSON object.'
		in: (self postJson: '"x"').
	self
		assertSingleError: 'Body must be a JSON object.'
		in: (self postJson: '42').
	self
		assertSingleError: 'Variables are invalid JSON.'
		in: (self postJson: '{"query":"{ hello }","variables":"nope"}').
	self
		assertSingleError: 'Variables are invalid JSON.'
		in: (self postJson: '{"query":"{ hello }","variables":5}').
	response := self postJson: '{bad'.
	self assert: response code equals: 200.
	json := self jsonOf: response.
	self deny: (json includesKey: 'data').
	self assert: (((json at: 'errors') first at: 'message') beginsWith:
			 'Body is not valid JSON: ')
]

{ #category : 'tests - POST' }
GQLHttpHandlerTest >> testPostJson [

	| response json |
	response := self postJson: '{"query":"{ hello }"}'.
	self assert: response code equals: 200.
	json := self jsonOf: response.
	self assert: ((json at: 'data') at: 'hello') equals: 'world'.
	"variables as a JSON object, or as a JSON-encoded string; null variables are accepted"
	json := self jsonOf: (self postJson:
			         '{"query":"query($n: String!) { greet(name: $n) }","variables":{"n":"A"}}').
	self assert: ((json at: 'data') at: 'greet') equals: 'Hello, A'.
	json := self jsonOf: (self postJson:
			         '{"query":"query($n: String!) { greet(name: $n) }","variables":"{\"n\":\"B\"}"}').
	self assert: ((json at: 'data') at: 'greet') equals: 'Hello, B'.
	json := self jsonOf: (self postJson:
			         '{"query":"{ hello }","variables":null,"operationName":null}').
	self assert: ((json at: 'data') at: 'hello') equals: 'world'
]

{ #category : 'tests - POST' }
GQLHttpHandlerTest >> testPostOperationName [

	| json |
	json := self jsonOf: (self postJson:
			         '{"query":"query A { hello } query B { greet(name: \"x\") }","operationName":"A"}').
	self assert: (json at: 'data') keys asArray equals: #( 'hello' ).
	"without operationName, several operations are a request error (no data)"
	self
		assertSingleError:
		'Must provide operation name if query contains multiple operations.'
		in:
		(self postJson: '{"query":"query A { hello } query B { hello }"}')
]

{ #category : 'tests - POST' }
GQLHttpHandlerTest >> testResolverErrorIsStill200WithDataAndErrors [

	| response json |
	response := self postJson: '{"query":"{ boom hello }"}'.
	self assert: response code equals: 200.
	json := self jsonOf: response.
	self assert: ((json at: 'data') at: 'boom') isNil.
	self assert: ((json at: 'data') at: 'hello') equals: 'world'.
	self
		assert: ((json at: 'errors') first at: 'message')
		equals: 'boom!'.
	self
		assert: ((json at: 'errors') first at: 'path')
		equals: #( 'boom' ).
	"GraphQL syntax errors are also 200 with an errors-only body"
	response := self postJson: '{"query":"{ hello "}'.
	self assert: response code equals: 200.
	json := self jsonOf: response.
	self deny: (json includesKey: 'data').
	self assert:
		(((json at: 'errors') first at: 'message') beginsWith:
			 'Syntax Error')
]
