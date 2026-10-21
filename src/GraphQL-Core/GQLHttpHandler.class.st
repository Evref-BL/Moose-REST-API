"
I translate HTTP requests (ZnRequest) into GraphQL executions and answer ZnResponses following the GraphQL-over-HTTP conventions.

- OPTIONS (any path): 204 with CORS headers (preflight).
- GET <path>?query=...&operationName=...&variables=<json>
- POST <path> with application/json body {""query"": ..., ""operationName"": ..., ""variables"": {...}} or application/graphql raw query body.
- Other methods: 405.
- Unknown paths: 404.

Every response carries CORS headers and a JSON body with 'data' and/or 'errors'. GraphQL errors are answered with HTTP 200.
#handleRequest: never raises.

Usage:
	handler := GQLHttpHandler schema: aSchema.
	handler contextBlock: [ :znRequest | ... ].
	response := handler handleRequest: aZnRequest.
"
Class {
	#name : 'GQLHttpHandler',
	#superclass : 'Object',
	#instVars : [
		'schema',
		'executor',
		'path',
		'contextBlock',
		'debug'
	],
	#category : 'GraphQL-Core-Server',
	#package : 'GraphQL-Core',
	#tag : 'Server'
}

{ #category : 'instance creation' }
GQLHttpHandler class >> schema: aGQLSchema [

	^ self new
		  schema: aGQLSchema;
		  yourself
]

{ #category : 'private - responses' }
GQLHttpHandler >> addCorsHeadersTo: aResponse [
	"Add permissive CORS headers so browser clients served from another origin can reach the endpoint."

	aResponse headers
		at: 'Access-Control-Allow-Origin' put: '*';
		at: 'Access-Control-Allow-Methods' put: 'GET, POST, OPTIONS';
		at: 'Access-Control-Allow-Headers' put: 'content-type, accept'.
	^ aResponse
]

{ #category : 'private - handling' }
GQLHttpHandler >> basicHandleRequest: aRequest [
	"Dispatch on method and path. May raise; see #handleRequest: for the safe entry point."

	| method |
	method := aRequest method.
	method = #OPTIONS ifTrue: [ ^ self preflightResponse ].
	(self isGraphQLPath: aRequest) ifFalse: [
		^ self notFoundResponse: aRequest ].
	method = #GET ifTrue: [ ^ self handleGet: aRequest ].
	method = #POST ifTrue: [ ^ self handlePost: aRequest ].
	^ self methodNotAllowedResponse: aRequest
]

{ #category : 'private - parsing' }
GQLHttpHandler >> bodyStringOf: aRequest [
	"Answer the request body as a String (UTF-8 decoded when binary), or an empty String."

	| contents |
	aRequest hasEntity ifFalse: [ ^ '' ].
	contents := aRequest contents.
	contents ifNil: [ ^ '' ].
	contents isString ifTrue: [ ^ contents ].
	^ contents asByteArray utf8Decoded
]

{ #category : 'accessing' }
GQLHttpHandler >> contextBlock [

	^ contextBlock
]

{ #category : 'accessing' }
GQLHttpHandler >> contextBlock: aBlockOrNil [
	"A block evaluated (with #cull: the ZnRequest) for each request to build the execution context."

	contextBlock := aBlockOrNil
]

{ #category : 'accessing' }
GQLHttpHandler >> debug [

	^ debug
]

{ #category : 'accessing' }
GQLHttpHandler >> debug: aBoolean [

	debug := aBoolean
]

{ #category : 'private - responses' }
GQLHttpHandler >> errorResponse: aMessage status: anInteger [
	"Answer a GraphQL-shaped error response: {""errors"": [{""message"": aMessage}]}."

	| error result |
	error := OrderedDictionary new.
	error at: 'message' put: aMessage asString.
	result := OrderedDictionary new.
	result at: 'errors' put: (Array with: error).
	^ self jsonResponse: result status: anInteger
]

{ #category : 'private - handling' }
GQLHttpHandler >> executeQuery: aQueryString operationName: anOperationName variables: aDictionaryOrNil request: aRequest [
	"Execute the query and answer a 200 JSON response. GraphQL errors are part of the result body."

	| query context result |
	query := self nonEmpty: aQueryString.
	(query isNil or: [ query isString not ]) ifTrue: [
		^ self errorResponse: 'Must provide query string.' status: 200 ].
	context := contextBlock ifNotNil: [ :block | block cull: aRequest ].
	result := executor
		          execute: query
		          operationName: (self nonEmpty: anOperationName)
		          variables: aDictionaryOrNil
		          context: context.
	^ self jsonResponse: result
]

{ #category : 'accessing' }
GQLHttpHandler >> executor [

	^ executor
]

{ #category : 'accessing' }
GQLHttpHandler >> executor: aGQLExecutor [

	executor := aGQLExecutor.
	schema := aGQLExecutor schema
]

{ #category : 'private - handling' }
GQLHttpHandler >> handleGet: aRequest [
	"Handle GET /graphql?query=...&operationName=...&variables={...}"

	| uri variables |
	uri := aRequest uri.
	variables := self
		             parseVariables:
		             (uri queryAt: 'variables' ifAbsent: [ nil ])
		             ifInvalid: [
		             ^ self
			               errorResponse: 'Variables are invalid JSON.'
			               status: 200 ].
	^ self
		  executeQuery: (uri queryAt: 'query' ifAbsent: [ nil ])
		  operationName: (uri queryAt: 'operationName' ifAbsent: [ nil ])
		  variables: variables
		  request: aRequest
]

{ #category : 'private - handling' }
GQLHttpHandler >> handlePost: aRequest [
	"Handle POST with a JSON body {query, operationName?, variables?} or an application/graphql body."

	| body json variables mimeType |
	body := self bodyStringOf: aRequest.
	mimeType := aRequest hasEntity ifTrue: [ aRequest contentType ].
	(mimeType notNil and: [
			 mimeType main asLowercase = 'application' and: [
				 mimeType sub asLowercase = 'graphql' ] ]) ifTrue: [
			^ self
				  executeQuery: body
				  operationName:
				  (aRequest uri queryAt: 'operationName' ifAbsent: [ nil ])
				  variables: nil
				  request: aRequest ].
	(self nonEmpty: body) ifNil: [
		^ self errorResponse: 'Must provide query string.' status: 200 ].
	json := [ NeoJSONReader fromString: body ]
		        on: Error
		        do: [ :e |
				        ^ self
					          errorResponse:
					          'Body is not valid JSON: ' , e messageText asString
					          status: 200 ].
	json isArray ifTrue: [
		^ self
			  errorResponse: 'Batched queries are not supported.'
			  status: 200 ].
	json isDictionary ifFalse: [
		^ self errorResponse: 'Body must be a JSON object.' status: 200 ].
	variables := self
		             parseVariables:
		             (json at: 'variables' ifAbsent: [ nil ])
		             ifInvalid: [
		             ^ self
			               errorResponse: 'Variables are invalid JSON.'
			               status: 200 ].
	^ self
		  executeQuery: (json at: 'query' ifAbsent: [ nil ])
		  operationName: (json at: 'operationName' ifAbsent: [ nil ])
		  variables: variables
		  request: aRequest
]

{ #category : 'handling' }
GQLHttpHandler >> handleRequest: aRequest [
	"Answer a ZnResponse for aRequest. Never raises: any unexpected error becomes a JSON error response."

	^ [ self basicHandleRequest: aRequest ]
		  on: Error
		  do: [ :e | self internalErrorResponse: e ]
]

{ #category : 'initialization' }
GQLHttpHandler >> initialize [

	super initialize.
	path := '/graphql'.
	debug := false
]

{ #category : 'private - responses' }
GQLHttpHandler >> internalErrorResponse: anException [
	"Answer a JSON error response for an unexpected failure. Never raises: falls back to a hard-coded body."

	^ [
		  | error result |
		  error := OrderedDictionary new.
		  error at: 'message' put: 'Internal server error.'.
		  self isDebug ifTrue: [
				  | extensions |
				  extensions := OrderedDictionary new.
				  extensions at: 'exception' put: anException class name asString.
				  extensions
					  at: 'description'
					  put: anException description asString.
				  error at: 'extensions' put: extensions ].
		  result := OrderedDictionary new.
		  result at: 'errors' put: (Array with: error).
		  self jsonResponse: result status: 200 ]
		  on: Error
		  do: [ :e |
				  | response |
				  response := ZnResponse ok: (ZnEntity
						               with:
						               '{"errors":[{"message":"Internal server error."}]}'
						               type: ZnMimeType applicationJson).
				  [ self addCorsHeadersTo: response ]
					  on: Error
					  do: [ :ignored | "keep the bare response" ].
				  response ]
]

{ #category : 'testing' }
GQLHttpHandler >> isDebug [

	^ debug == true
]

{ #category : 'testing' }
GQLHttpHandler >> isGraphQLPath: aRequest [
	"Accept the configured path (with or without trailing '/') and the root path '/'."

	| requested |
	requested := aRequest uri pathPrintString ifNil: [ '/' ].
	requested isEmpty ifTrue: [ requested := '/' ].
	[ requested size > 1 and: [ requested last = $/ ] ] whileTrue: [
		requested := requested allButLast ].
	^ requested = '/' or: [ requested = path ]
]

{ #category : 'private - responses' }
GQLHttpHandler >> jsonResponse: anObject [

	^ self jsonResponse: anObject status: 200
]

{ #category : 'private - responses' }
GQLHttpHandler >> jsonResponse: anObject status: anInteger [

	^ self
		  jsonStringResponse: (NeoJSONWriter toString: anObject)
		  status: anInteger
]

{ #category : 'private - responses' }
GQLHttpHandler >> jsonStringResponse: aJsonString status: anInteger [
	"Answer a ZnResponse with the given JSON text as body, the given status code and CORS headers."

	| response |
	response := ZnResponse statusLine: (ZnStatusLine code: anInteger).
	response entity: (ZnEntity
			 with: aJsonString
			 type: (ZnMimeType fromString: 'application/json;charset=utf-8')).
	self addCorsHeadersTo: response.
	^ response
]

{ #category : 'private - responses' }
GQLHttpHandler >> methodNotAllowedResponse: aRequest [

	| response |
	response := self
		            errorResponse:
		            'Method not allowed: ' , aRequest method asString
		            status: 405.
	response headers at: 'Allow' put: 'GET, POST, OPTIONS'.
	^ response
]

{ #category : 'private - parsing' }
GQLHttpHandler >> nonEmpty: aStringOrNil [
	"Answer nil for nil or empty (blank) strings, the argument otherwise."

	aStringOrNil ifNil: [ ^ nil ].
	(aStringOrNil isString and: [ aStringOrNil trimBoth isEmpty ])
		ifTrue: [ ^ nil ].
	^ aStringOrNil
]

{ #category : 'private - responses' }
GQLHttpHandler >> notFoundResponse: aRequest [

	^ self
		  errorResponse: 'Not found: ' , aRequest uri pathPrintString
		  status: 404
]

{ #category : 'private - parsing' }
GQLHttpHandler >> parseVariables: anObject ifInvalid: aBlock [
	"Answer a Dictionary of variables (or nil) from nil, a Dictionary or a JSON string.
	Evaluate aBlock when anObject cannot be interpreted as a JSON object."

	| value parsed |
	value := self nonEmpty: anObject.
	value ifNil: [ ^ nil ].
	value isDictionary ifTrue: [ ^ value ].
	value isString ifFalse: [ ^ aBlock value ].
	parsed := [ NeoJSONReader fromString: value ]
		          on: Error
		          do: [ :e | ^ aBlock value ].
	parsed ifNil: [ ^ nil ].
	parsed isDictionary ifFalse: [ ^ aBlock value ].
	^ parsed
]

{ #category : 'accessing' }
GQLHttpHandler >> path [

	^ path
]

{ #category : 'accessing' }
GQLHttpHandler >> path: aString [
	"Set the endpoint path. A leading '/' is added when missing; trailing '/' are removed."

	| normalized |
	normalized := aString
		              ifNil: [ '' ]
		              ifNotNil: [ aString asString trimBoth ].
	(normalized beginsWith: '/') ifFalse: [
		normalized := '/' , normalized ].
	[ normalized size > 1 and: [ normalized last = $/ ] ] whileTrue: [
		normalized := normalized allButLast ].
	path := normalized
]

{ #category : 'private - responses' }
GQLHttpHandler >> preflightResponse [
	"Answer the CORS preflight response (204 No Content)."

	| response |
	response := ZnResponse noContent.
	self addCorsHeadersTo: response.
	response headers at: 'Access-Control-Max-Age' put: '86400'.
	^ response
]

{ #category : 'accessing' }
GQLHttpHandler >> schema [

	^ schema
]

{ #category : 'accessing' }
GQLHttpHandler >> schema: aGQLSchema [

	schema := aGQLSchema.
	executor := GQLExecutor schema: aGQLSchema
]
