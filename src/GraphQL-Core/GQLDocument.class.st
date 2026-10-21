Class {
	#name : 'GQLDocument',
	#superclass : 'GQLNode',
	#instVars : [
		'definitions'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLDocument >> definitions [

	^ definitions
]

{ #category : 'accessing' }
GQLDocument >> definitions: anObject [

	definitions := anObject
]

{ #category : 'accessing' }
GQLDocument >> fragments [
	"Answer a Dictionary fragment name -> GQLFragmentDefinition"

	| result |
	result := Dictionary new.
	definitions do: [ :each | each isFragmentDefinition ifTrue: [ result at: each name put: each ] ].
	^ result
]

{ #category : 'initialization' }
GQLDocument >> initialize [

	super initialize.
	definitions := OrderedCollection new
]

{ #category : 'testing' }
GQLDocument >> isDocument [

	^ true
]

{ #category : 'accessing' }
GQLDocument >> operationNamed: aString [
	"Answer the operation named aString, or nil"

	^ self operations detect: [ :each | each name = aString ] ifNone: [ nil ]
]

{ #category : 'accessing' }
GQLDocument >> operations [

	^ definitions select: [ :each | each isOperationDefinition ]
]
