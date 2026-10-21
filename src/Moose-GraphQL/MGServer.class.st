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
		'Current'
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
MGServer class >> start [
	"Start on the default port (4000)"
	^ self startOn: self defaultPort
]

{ #category : 'starting' }
MGServer class >> startOn: aPort [
	"Stop any running server and start a new one on aPort serving MGSchema default"
	| serverClass server |
	serverClass := self httpServerClass ifNil: [
		^ self error: 'GQLHttpServer is not available: load the GraphQL HTTP server first' ].
	self stop.
	server := serverClass on: aPort schema: MGSchema default.
	server contextBlock: [ :request | MGRegistry new ].
	server start.
	^ Current := server
]

{ #category : 'starting' }
MGServer class >> stop [
	"Stop the running server, if any (never raises)"
	Current ifNil: [ ^ self ].
	[ Current stop ] on: Error do: [ :e | e return: nil ].
	Current := nil
]
