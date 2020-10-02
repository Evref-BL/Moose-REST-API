"
Please comment me using the following template inspired by Class Responsibility Collaborator (CRC) design:

For the Class part:  State a one line summary. For example, ""I represent a paragraph of text"".

For the Responsibility part: Three sentences about my main responsibilities - what I do, what I know.

For the Collaborators Part: State my main collaborators and one line about how I interact with them. 

Public API and Key Messages

- message one   
- message two 
- (for bonus points) how to create instances.

   One simple example is simply gorgeous.
 
Internal Representation and Key Implementation Points.


    Implementation Points
"
Class {
	#name : #MRAPIModel,
	#superclass : #MRAPI,
	#category : #'Moose-REST-API'
}

{ #category : #api }
MRAPIModel class >> entities: aRequest [
	"model/<modelID>/entities?page=X&numberOfItems"

	<REST_API: 'GET' versions: #('v1') pattern: 'model/<modelID>/entities'>
	| model pageNumber numberOfItems |
	pageNumber := (aRequest queryOrFormParam: #page ifAbsent: [ 0 ]) asInteger.
	numberOfItems := (aRequest queryOrFormParam: #numberOfItems ifAbsent: [ 15 ]) asInteger.
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	^ MROutput json value: (TeaResponse ok body: (model entities copyFrom: numberOfItems * pageNumber + 1 to: numberOfItems * (pageNumber + 1)))
]

{ #category : #api }
MRAPIModel class >> entity: aRequest [
	<REST_API: 'GET' versions: #('v1') pattern: 'model/<modelID>/entity/<entityID>'>
	| model entityID |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	entityID := (aRequest at: #entityID) asInteger.
	^ MROutput json value: (TeaResponse ok body: (model detect: [ :el | el mooseID = entityID ]))
]

{ #category : #api }
MRAPIModel class >> subTypesOf: aRequest [
	"model/<modelID>/subTypesOf?type=TheType&page=X&numberOfItems"

	<REST_API: 'GET' versions: #('v1') pattern: 'model/<modelID>/subTypesOf'>
	| model pageNumber numberOfItems class result |
	pageNumber := (aRequest queryOrFormParam: #page ifAbsent: [ 0 ]) asInteger.
	numberOfItems := (aRequest queryOrFormParam: #numberOfItems ifAbsent: [ 15 ]) asInteger.
	class := self class environment
		at: (aRequest queryOrFormParam: #type ifAbsent: [ ^ MROutput json value: TeaResponse notFound ]) asSymbol
		ifAbsent: [ ^ MROutput json value: TeaResponse notFound ].

	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	result := Dictionary new.
	result at: #'size' put: (model allWithSubTypesOf: class) size.
	result at: #'data' put: ((model allWithSubTypesOf: class) asOrderedCollection copyFrom: numberOfItems * pageNumber + 1 to: numberOfItems * (pageNumber + 1)).
	^ MROutput json value: (TeaResponse ok body: (result))
]
