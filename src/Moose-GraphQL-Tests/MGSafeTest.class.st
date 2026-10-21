"
Unit tests for MGSafe: printing of arbitrary values (never raising), take:from: normalisation and entitiesIn: filtering.
"
Class {
	#name : 'MGSafeTest',
	#superclass : 'MGTestCase',
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'tests - misc' }
MGSafeTest >> testDoDefaultAndIsEntity [

	self assert: (MGSafe do: [ 1 + 1 ] default: 0) equals: 2.
	self assert: (MGSafe do: [ 1 / 0 ] default: 0) equals: 0.
	"A block default is evaluated, and a raising default answers nil"
	self
		assert: (MGSafe do: [ nil foo ] default: [ #fallback ])
		equals: #fallback.
	self assert: (MGSafe do: [ nil foo ] default: [ nil bar ]) isNil.
	self assert: (MGSafe isEntity: class1).
	self deny: (MGSafe isEntity: nil).
	self deny: (MGSafe isEntity: 'Class1').
	self deny: (MGSafe isEntity: model)
]

{ #category : 'tests - entities' }
MGSafeTest >> testEntitiesIn [
	"entitiesIn: keeps only Moose entities: nil -> empty, single entity -> one element, non-entity -> empty, mixed collection -> its entities"

	self assert: (MGSafe entitiesIn: nil) isEmpty.
	self assert: (MGSafe entitiesIn: class1) asArray equals: { class1 }.
	self assert: (MGSafe entitiesIn: 42) isEmpty.
	self assert: (MGSafe entitiesIn: 'abc') isEmpty.
	self
		assert: (MGSafe entitiesIn: {
					 1.
					 m1.
					 'x'.
					 nil.
					 a1 }) asArray
		equals: {
				m1.
				a1 }.
	self assert: (MGSafe entitiesIn: class1 methods) asArray equals: {
			m1.
			m2 }
]

{ #category : 'tests - take' }
MGSafeTest >> testNormalizeTake [

	self assert: (MGSafe normalizeTake: nil) equals: 100.
	self assert: (MGSafe normalizeTake: -1) equals: 100.
	self assert: (MGSafe normalizeTake: 0) equals: 0.
	self assert: (MGSafe normalizeTake: 7) equals: 7.
	self assert: (MGSafe normalizeTake: 5000) equals: 1000.
	self assert: (MGSafe normalizeTake: '12') equals: 12.
	self assert: (MGSafe normalizeTake: #notANumber) equals: 100
]

{ #category : 'tests - printValue' }
MGSafeTest >> testPrintValueCollections [
	"Collections print as '<n> items: (first 5 elements, …)'; empty collections as '0 items'"

	self assert: (MGSafe printValue: #(  )) equals: '0 items'.
	self
		assert: (MGSafe printValue: #( 1 2 3 ))
		equals: '3 items: (1, 2, 3)'.
	self
		assert: (MGSafe printValue: (1 to: 7) asArray)
		equals: '7 items: (1, 2, 3, 4, 5, …)'.
	"Entities inside a collection are named by their mooseName"
	self
		assert:
		(MGSafe printValue: (OrderedCollection with: m1 with: class1))
		equals: '2 items: (Class1.m1, Class1)'
]

{ #category : 'tests - printValue' }
MGSafeTest >> testPrintValueEntityAndGroup [
	"A single entity prints as its mooseName; a Moose group is treated like a collection"

	self assert: (MGSafe printValue: class1) equals: 'Class1'.
	self assert: (MGSafe printValue: m1) equals: 'Class1.m1'.
	self
		assert: (MGSafe printValue: class1 methods)
		equals: '2 items: (Class1.m1, Class1.m2)'
]

{ #category : 'tests - printValue' }
MGSafeTest >> testPrintValueNeverRaises [
	"An object whose printOn: raises is rendered as '<error: message>' instead of signalling"

	| printed |
	self
		shouldnt: [ printed := MGSafe printValue: MGRaisingPrintObject new ]
		raise: Error.
	self assert: (printed beginsWith: '<error').
	self assert: (printed includesSubstring: 'print failure').
	"Same inside a collection: the element name falls back to the class name"
	self
		shouldnt: [
		printed := MGSafe printValue: { MGRaisingPrintObject new } ]
		raise: Error.
	self assert: printed isString
]

{ #category : 'tests - printValue' }
MGSafeTest >> testPrintValueScalars [
	"nil stays nil (GraphQL null); strings and symbols print without quotes; numbers and booleans use printString"

	self assert: (MGSafe printValue: nil) isNil.
	self assert: (MGSafe printValue: 'abc') equals: 'abc'.
	self assert: (MGSafe printValue: #foo) equals: 'foo'.
	self assert: (MGSafe printValue: 42) equals: '42'.
	self assert: (MGSafe printValue: 1.5) equals: '1.5'.
	self assert: (MGSafe printValue: 3 / 4) equals: '(3/4)'.
	self assert: (MGSafe printValue: true) equals: 'true'.
	self assert: (MGSafe printValue: false) equals: 'false'
]

{ #category : 'tests - printValue' }
MGSafeTest >> testPrintValueTruncatesLongStrings [
	"Strings longer than maxPrintSize (1000) are cut and end with an ellipsis; shorter ones are untouched"

	| long printed exact |
	long := String new: 1500 withAll: $x.
	printed := MGSafe printValue: long.
	self assert: MGSafe maxPrintSize equals: 1000.
	self assert: printed size equals: 1001.
	self assert: printed last equals: $….
	self assert: (printed first: 1000) equals: (long first: 1000).
	exact := String new: 1000 withAll: $y.
	self assert: (MGSafe printValue: exact) equals: exact
]

{ #category : 'tests - take' }
MGSafeTest >> testTakeFrom [
	"take:from: answers an Array; nil or negative take means defaultTake (100), huge take is capped at maxTake (1000)"

	| big |
	big := (1 to: 5000) asArray.
	self
		assert: (MGSafe take: nil from: big) size
		equals: MGSchema defaultTake.
	self
		assert: (MGSafe take: -3 from: big) size
		equals: MGSchema defaultTake.
	self
		assert: (MGSafe take: 1000000 from: big) size
		equals: MGSchema maxTake.
	self assert: (MGSafe take: 3 from: big) equals: #( 1 2 3 ).
	self assert: (MGSafe take: 0 from: big) equals: #(  ).
	self assert: (MGSafe take: 10 from: #( 1 2 )) equals: #( 1 2 ).
	self assert: (MGSafe take: 10 from: nil) equals: #(  ).
	self assert: (MGSafe take: 1 from: class1 methods) equals: { m1 }
]
