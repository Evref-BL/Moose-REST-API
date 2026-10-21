"
I am a small HTTP server exposing a GraphQL schema through a GQLHttpHandler, on top of Zinc (ZnServer). I bind to the loopback interface only.

Usage:
	server := (GQLHttpServer on: 4000 schema: aSchema)
		contextBlock: [ :znRequest | MyContext new ];
		debug: false;
		start.
	server url. ""'http://localhost:4000/graphql'""
	server isRunning.
	server stop.

	""Default port 4000:""
	(GQLHttpServer schema: aSchema) start.

Endpoints: GET/POST on /graphql (configurable with #path:) and on '/'; OPTIONS on any path answers the CORS preflight. See GQLHttpHandler for the HTTP contract.
"
Class {
	#name : 'GQLHttpServer',
	#superclass : 'Object',
	#instVars : [
		'server',
		'handler',
		'port'
	],
	#category : 'GraphQL-Core-Server',
	#package : 'GraphQL-Core',
	#tag : 'Server'
}

{ #category : 'instance creation' }
GQLHttpServer class >> on: aPortNumber schema: aGQLSchema [

	^ self new
		  setPort: aPortNumber handler: (GQLHttpHandler schema: aGQLSchema);
		  yourself
]

{ #category : 'instance creation' }
GQLHttpServer class >> schema: aGQLSchema [

	^ self on: 4000 schema: aGQLSchema
]

{ #category : 'configuring' }
GQLHttpServer >> contextBlock: aBlock [
	"aBlock is evaluated with #cull: the ZnRequest to build each request's execution context."

	handler contextBlock: aBlock
]

{ #category : 'configuring' }
GQLHttpServer >> debug: aBoolean [

	handler debug: aBoolean
]

{ #category : 'accessing' }
GQLHttpServer >> handler [

	^ handler
]

{ #category : 'testing' }
GQLHttpServer >> isRunning [

	^ server notNil and: [ server isRunning ]
]

{ #category : 'accessing' }
GQLHttpServer >> path [

	^ handler path
]

{ #category : 'configuring' }
GQLHttpServer >> path: aString [

	handler path: aString
]

{ #category : 'accessing' }
GQLHttpServer >> port [

	^ port
]

{ #category : 'printing' }
GQLHttpServer >> printOn: aStream [

	super printOn: aStream.
	aStream
		nextPut: $(;
		nextPutAll: self url;
		nextPutAll: (self isRunning
				 ifTrue: [ ' running' ]
				 ifFalse: [ ' stopped' ]);
		nextPut: $)
]

{ #category : 'initialization' }
GQLHttpServer >> setPort: aPortNumber handler: aGQLHttpHandler [

	port := aPortNumber.
	handler := aGQLHttpHandler
]

{ #category : 'running' }
GQLHttpServer >> start [
	"Start (or restart) listening on the loopback interface. Answer the receiver."

	self stop.
	server := (ZnServer on: port)
		          bindingAddress: NetNameResolver loopBackAddress;
		          onRequestRespond: [ :request |
			          handler handleRequest: request ];
		          yourself.
	server start.
	^ self
]

{ #category : 'running' }
GQLHttpServer >> stop [
	"Stop the underlying Zinc server, if any."

	server ifNotNil: [
			server stop.
			server := nil ]
]

{ #category : 'accessing' }
GQLHttpServer >> url [
	"Answer the GraphQL endpoint URL as a String."

	^ 'http://localhost:' , port printString , handler path
]
