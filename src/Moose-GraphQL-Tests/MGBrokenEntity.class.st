"
Test helper: a non-Famix MooseEntity with a broken meta-description.
When #raising is false its #metadescription answers nil; when true, #metadescription, #mooseName and #name raise an Error.
Used by MGResilienceTest to check that the GraphQL layer never lets exceptions escape.
"
Class {
	#name : 'MGBrokenEntity',
	#superclass : 'MooseEntity',
	#instVars : [
		'raising'
	],
	#category : 'Moose-GraphQL-Tests-Support',
	#package : 'Moose-GraphQL-Tests',
	#tag : 'Support'
}

{ #category : 'meta' }
MGBrokenEntity >> metadescription [

	raising == true ifTrue: [ ^ self error: 'broken metadescription' ].
	^ nil
]

{ #category : 'accessing' }
MGBrokenEntity >> mooseName [

	raising == true ifTrue: [ ^ self error: 'broken mooseName' ].
	^ 'brokenEntity'
]

{ #category : 'accessing' }
MGBrokenEntity >> name [

	raising == true ifTrue: [ ^ self error: 'broken name' ].
	^ nil
]

{ #category : 'accessing' }
MGBrokenEntity >> raising: aBoolean [

	raising := aBoolean
]
