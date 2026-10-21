"
Abstract fixture for the Moose-GraphQL tests.

setUp installs a small FamixTest1Model named 'MGTestModel' in MooseModel root:
- Class1 with methods m1, m2 and attribute a1
- Class2 with method m3
tearDown removes it (robustly) so MooseModel root is left clean even when a test fails.

Helpers: #query:, #query:variables: (execute against MGSchema default with a fresh registry snapshot), #registry, #modelId, #idOf:.
"
Class {
	#name : 'MGTestCase',
	#superclass : 'TestCase',
	#instVars : [
		'model',
		'class1',
		'class2',
		'm1',
		'm2',
		'm3',
		'a1',
		'registry'
	],
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'testing' }
MGTestCase class >> isAbstract [

	^ self == MGTestCase
]

{ #category : 'helpers' }
MGTestCase >> dataOf: aString [

	^ self dataOf: aString variables: nil
]

{ #category : 'helpers' }
MGTestCase >> dataOf: aString variables: aDictionaryOrNil [
	"Execute the query, assert it produced no GraphQL error and answer its 'data' entry"

	| response |
	response := self query: aString variables: aDictionaryOrNil.
	self assert: (response includesKey: 'errors') not description: [
			'Unexpected errors: '
			, (response at: 'errors' ifAbsent: [ #(  ) ]) printString ].
	^ response at: 'data'
]

{ #category : 'helpers' }
MGTestCase >> idOf: anEntity [
	"Opaque GraphQL id <modelId>:<mooseID> of anEntity"

	^ self registry idOfEntity: anEntity
]

{ #category : 'helpers' }
MGTestCase >> modelId [
	"Id of the fixture model, computed by the registry (do not assume '1': other models may be installed)"

	^ self registry idOfModel: model
]

{ #category : 'accessing' }
MGTestCase >> modelName [

	^ 'MGTestModel'
]

{ #category : 'helpers' }
MGTestCase >> query: aString [

	^ self query: aString variables: nil
]

{ #category : 'helpers' }
MGTestCase >> query: aString variables: aDictionaryOrNil [
	"Execute aString against the cached Moose schema with a fresh registry; answer the response dictionary ('data' / 'errors')"

	^ MGSchema default
		  execute: aString
		  operationName: nil
		  variables: aDictionaryOrNil
		  context: MGRegistry new
]

{ #category : 'helpers' }
MGTestCase >> registry [
	"A registry whose model snapshot includes the fixture model"

	^ registry ifNil: [ registry := MGRegistry new ]
]

{ #category : 'running' }
MGTestCase >> setUp [
	"Build and install the MGTestModel fixture (see class comment)"

	super setUp.
	model := FamixTest1Model new name: self modelName.
	class1 := FamixTest1Class named: 'Class1'.
	class2 := FamixTest1Class named: 'Class2'.
	m1 := FamixTest1Method named: 'm1'.
	m2 := FamixTest1Method named: 'm2'.
	m3 := FamixTest1Method named: 'm3'.
	a1 := FamixTest1Attribute named: 'a1'.
	class1
		addMethod: m1;
		addMethod: m2;
		addAttribute: a1.
	class2 addMethod: m3.
	model addAll: {
			class1.
			class2.
			m1.
			m2.
			m3.
			a1 }.
	model install
]

{ #category : 'running' }
MGTestCase >> tearDown [
	"Remove the fixture model (and any leftover test model whose name starts with 'MGTest') from MooseModel root, whatever happened during the test"

	[ model ifNotNil: [ model remove ] ]
		on: Error
		do: [ :e | e return: nil ].
	[
		(MooseModel root asArray select: [ :m |
				 [ m name asString beginsWith: 'MGTest' ]
					 on: Error
					 do: [ :e | e return: false ] ]) do: [ :m |
				[ m remove ]
					on: Error
					do: [ :e |
							[ MooseModel root remove: m ifAbsent: [ nil ] ]
								on: Error
								do: [ :e2 | e2 return: nil ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	registry := nil.
	super tearDown
]
