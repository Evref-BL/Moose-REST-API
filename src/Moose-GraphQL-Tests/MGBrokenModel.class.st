"
Test helper: a MooseModel whose #entities and #size raise an Error. Never installed in MooseModel root; handed to an MGRegistry via #useModels: to check resilience.
"
Class {
	#name : 'MGBrokenModel',
	#superclass : 'MooseModel',
	#category : 'Moose-GraphQL-Tests-Support',
	#package : 'Moose-GraphQL-Tests',
	#tag : 'Support'
}

{ #category : 'accessing' }
MGBrokenModel >> entities [

	^ self error: 'broken entities'
]

{ #category : 'accessing' }
MGBrokenModel >> size [

	^ self error: 'broken size'
]
