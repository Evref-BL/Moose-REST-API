"
Test helper: an object whose printOn: always raises an Error. Used to check that MGSafe class>>printValue: never lets an exception escape.
"
Class {
	#name : 'MGRaisingPrintObject',
	#superclass : 'Object',
	#category : 'Moose-GraphQL-Tests-Support',
	#package : 'Moose-GraphQL-Tests',
	#tag : 'Support'
}

{ #category : 'printing' }
MGRaisingPrintObject >> printOn: aStream [

	self error: 'print failure'
]
