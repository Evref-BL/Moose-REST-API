Class {
	#name : 'GQLSelectionSet',
	#superclass : 'GQLNode',
	#instVars : [
		'selections'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'initialization' }
GQLSelectionSet >> initialize [

	super initialize.
	selections := OrderedCollection new
]

{ #category : 'accessing' }
GQLSelectionSet >> selections [

	^ selections
]

{ #category : 'accessing' }
GQLSelectionSet >> selections: anObject [

	selections := anObject
]
