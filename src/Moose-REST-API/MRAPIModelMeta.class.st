Class {
	#name : #MRAPIModelMeta,
	#superclass : #MRAPI,
	#category : #'Moose-REST-API'
}

{ #category : #'as yet unclassified' }
MRAPIModelMeta class >> modelMeta: aRequest [
	<REST_API: 'GET' versions: #('v1') pattern: 'model/<modelID>/meta'>
	| model types |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	types := ((model metamodel classes
		reject: [ :a | 
			a implementingClass isTrait
				or: [ (model allWithSubTypesOf: a implementingClass) isEmpty ] ])
		sorted: #name ascending)
		collect: [ :fm3Class | 
			{(#name -> fm3Class name).
			(#implementationName -> fm3Class implementingClass name)}
				asDictionary ].
	^ MROutput json value: (TeaResponse ok body: types)
]
