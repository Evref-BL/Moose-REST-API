"
I start/stop the GraphQL HTTP endpoint serving MGSchema over the installed Moose models (one MGRegistry per request).

Usage:
	MGServer start.			""port 4000""
	MGServer startOn: 4000.
	""then point fluid (or any GraphQL client) to http://localhost:4000/graphql""
	MGServer isRunning.
	MGServer current.		""the underlying GQLHttpServer, or nil""
	MGServer stop.

I rely on GQLHttpServer (GraphQL-Core, #on:schema:, #contextBlock:, #start, #stop). If it is not loaded, #startOn: signals an Error explaining it.
"
Class {
	#name : 'MGServer',
	#superclass : 'Object',
	#classVars : [
		'Current',
		'CurrentModel'
	],
	#category : 'Moose-GraphQL-Server',
	#package : 'Moose-GraphQL',
	#tag : 'Server'
}

{ #category : 'accessing' }
MGServer class >> current [
	"The running GQLHttpServer, or nil"
	^ Current
]

{ #category : 'accessing' }
MGServer class >> currentModel [
	"The Moose model served in model mode, or nil (generic mode or no server)"

	^ CurrentModel
]

{ #category : 'accessing' }
MGServer class >> defaultPort [
	^ 4000
]

{ #category : 'private' }
MGServer class >> httpServerClass [
	"GQLHttpServer when loaded, nil otherwise (looked up dynamically: the HTTP layer may be absent)"
	^ Smalltalk globals at: #GQLHttpServer ifAbsent: [ nil ]
]

{ #category : 'testing' }
MGServer class >> isRunning [
	^ Current notNil and: [
		(Current respondsTo: #isRunning)
			ifTrue: [ MGSafe do: [ Current isRunning ] default: false ]
			ifFalse: [ true ] ]
]

{ #category : 'starting' }
MGServer class >> restart [
	"Restart on the same port (default port when not running), rebuilding the schema: in model mode the concepts are recomputed from the current model types"

	| port model |
	port := (Current ifNotNil: [ :server | MGSafe do: [ server port ] default: nil ])
		        ifNil: [ self defaultPort ].
	model := CurrentModel.
	^ model
		  ifNil: [ self startOn: port ]
		  ifNotNil: [ self startOn: port model: model ]
]

{ #category : 'starting' }
MGServer class >> start [
	"Start on the default port (4000)"
	^ self startOn: self defaultPort
]

{ #category : 'starting' }
MGServer class >> startOn: aPort [
	"Stop any running server and start a new one on aPort serving MGSchema default (generic mode)"

	^ self
		  startOn: aPort
		  schema: MGSchema default
		  contextBlock: [ :request | MGRegistry new ]
]

{ #category : 'starting' }
MGServer class >> startOn: aPort model: aMooseModel [
	"Stop any running server and start a new one on aPort whose GraphQL concepts are the entity types of aMooseModel (model mode).
	The schema is a snapshot of the model types: use #restart after the model changed.
	The schema is built first: when aMooseModel has no entity to expose, MGEmptyModelError is signaled and any running server is left untouched."

	| schema server |
	schema := MGModelSchemaBuilder buildFor: aMooseModel.
	server := self
		          startOn: aPort
		          schema: schema
		          contextBlock: [ :request |
		          MGRegistry forModel: aMooseModel ].
	CurrentModel := aMooseModel.
	^ server
]

{ #category : 'private' }
MGServer class >> startOn: aPort schema: aGQLSchema contextBlock: aBlock [
	"Stop any running server (which clears CurrentModel) and start a new one on aPort serving aGQLSchema, each request getting the context answered by aBlock"

	| serverClass server |
	serverClass := self httpServerClass ifNil: [
		^ self error: 'GQLHttpServer is not available: load the GraphQL HTTP server first' ].
	self stop.
	server := serverClass on: aPort schema: aGQLSchema.
	server contextBlock: aBlock.
	server start.
	^ Current := server
]

{ #category : 'starting' }
MGServer class >> startOnModel: aMooseModel [
	"Start on the default port (4000) in model mode, see #startOn:model:"

	^ self startOn: self defaultPort model: aMooseModel
]

{ #category : 'stopping' }
MGServer class >> stop [
	"Stop the running server, if any (never raises)"

	CurrentModel := nil.
	Current ifNil: [ ^ self ].
	[ Current stop ] on: Error do: [ :e | e return: nil ].
	Current := nil
]
