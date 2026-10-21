"
I am signaled internally by GQLExecutor when a field cannot produce a value. The carried GQLError has already been recorded in the execution context when I am signaled; I am only used to propagate null values up to the nearest nullable field or list (GraphQL null propagation).
"
Class {
	#name : 'GQLFieldError',
	#superclass : 'Error',
	#instVars : [
		'gqlError'
	],
	#category : 'GraphQL-Core-Execution',
	#package : 'GraphQL-Core',
	#tag : 'Execution'
}

{ #category : 'signalling' }
GQLFieldError class >> signalFor: aGQLError [
	^ self new gqlError: aGQLError; signal
]

{ #category : 'accessing' }
GQLFieldError >> gqlError [
	^ gqlError
]

{ #category : 'accessing' }
GQLFieldError >> gqlError: aGQLError [
	gqlError := aGQLError
]

{ #category : 'accessing' }
GQLFieldError >> messageText [
	^ gqlError ifNil: [ super messageText ] ifNotNil: [ :e | e message ]
]
