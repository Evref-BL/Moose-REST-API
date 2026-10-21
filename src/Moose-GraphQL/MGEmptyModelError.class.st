"
I am signaled by MGModelSchemaBuilder (and so by MGServer class>>startOn:model:) when a Moose model has no entity to expose: no concrete FM3 class of its metamodel has an instance in the model, so no GraphQL concept (and no Query root field) can be generated.

	MGEmptyModelError signalForModelNamed: 'MyModel'

My messageText is 'Model <name> has no entity to expose'.
"
Class {
	#name : 'MGEmptyModelError',
	#superclass : 'Error',
	#instVars : [
		'modelName'
	],
	#category : 'Moose-GraphQL-Schema',
	#package : 'Moose-GraphQL',
	#tag : 'Schema'
}

{ #category : 'signalling' }
MGEmptyModelError class >> signalForModelNamed: aString [
	"Signal that the model named aString has no entity to expose"

	^ self new
		  modelName: aString;
		  signal
]

{ #category : 'accessing' }
MGEmptyModelError >> messageText [
	"Explicit message unless one was given"

	^ messageText ifNil: [
			  'Model ' , (modelName ifNil: [ '?' ]) asString
			  , ' has no entity to expose' ]
]

{ #category : 'accessing' }
MGEmptyModelError >> modelName [

	^ modelName
]

{ #category : 'accessing' }
MGEmptyModelError >> modelName: aString [

	modelName := aString
]
