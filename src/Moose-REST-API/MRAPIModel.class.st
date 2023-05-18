Class {
	#name : #MRAPIModel,
	#superclass : #MRAPI,
	#category : #'Moose-REST-API'
}

{ #category : #api }
MRAPIModel class >> entities: aRequest [

	"Return the list of entities of the model"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entities'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #array>
	| model pageNumber numberOfItems |
	pageNumber := (aRequest queryOrFormParam: #page ifAbsent: [ 0 ])
		              asInteger.
	numberOfItems := (aRequest
		                  queryOrFormParam: #numberOfItems
		                  ifAbsent: [ 15 ]) asInteger.
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	^ MROutput json value: (TeaResponse ok body: (model entities
				    copyFrom: numberOfItems * pageNumber + 1
				    to: numberOfItems * (pageNumber + 1)))
]

{ #category : #api }
MRAPIModel class >> entity: aRequest [

	"An endpoint to access information about the entity entityID of the model modelID"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityID>'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #object>
	| model entityID |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	entityID := (aRequest at: #entityID) asInteger.
	^ MROutput json value:
		  (TeaResponse ok body:
			   (model detect: [ :el | el mooseID = entityID ]))
]

{ #category : #api }
MRAPIModel class >> entityAttributes: aRequest [
	"Return the attributes and their value of a specific entity"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityID>/attributes'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #array>
	| entity metaProperties attributes |
	entity := self retrieveEntity: aRequest.
	metaProperties := entity mooseDescription allPrimitiveProperties 
		                  sorted: #name ascending.
	attributes := metaProperties collect: [ :att | 
		              { 
			              (#key -> att name).
			              (#value -> ([ entity mmGetProperty: att ]
				                on: Error
				                do: [ :e | e description ]) printString) }
			              asDictionary ].

	^ MROutput json value: (TeaResponse ok body: attributes)
]

{ #category : #api }
MRAPIModel class >> entityChildren: aRequest [

	"Return the children of an entity"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityID>/children'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #array>
	| model entityID |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	entityID := (aRequest at: #entityID) asInteger.
	^ MROutput json value: (TeaResponse ok body:
			   (model detect: [ :el | el mooseID = entityID ]) children)
]

{ #category : #api }
MRAPIModel class >> entitySourceCode: aRequest [

	"Return the source code of an entity"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityID>/sourceCode'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #object>
	| entity |
	entity := self retrieveEntity: aRequest.

	^ MROutput json value: (TeaResponse ok body: { 
				   ('body' -> (entity sourceAnchor
					     ifNotNil: [ :anchor | anchor sourceText ]
					     ifNil: [ 'No available text' ])).
				   (#file -> (entity sourceAnchor
					     ifNotNil: [ :anchor | anchor fileName ]
					     ifNil: [ 'No link' ])) } asDictionary)
]

{ #category : #api }
MRAPIModel class >> get: aRequest [

	"Return the basic meta information about a model "

	<REST_API: 'GET' versions: #( 'v1' ) pattern: 'model/<modelID>'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #object>
	| model modelID |
	modelID := (aRequest at: #modelID) asInteger.
	model := MooseModel root at: modelID.
	^ MROutput json value: (TeaResponse ok body: { 
				   ('name' -> model name).
				   ('id' -> modelID) } asDictionary)
]

{ #category : #'api - tree' }
MRAPIModel class >> rootEntities: aRequest [
	<REST_API: 'GET' versions: #('v1') pattern: 'model/<modelID>/rootEntities'>
	| model rootEntities |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	rootEntities := model select: [ :a | (a usesFamixTrait: TEntityMetaLevelDependency) and: [ a parents isEmpty ] ].
	^ MROutput json value: (TeaResponse ok body: rootEntities)
]

{ #category : #api }
MRAPIModel class >> subTypesOf: aRequest [

	"Return the subtypes of an entity"
	"model/<modelID>/subTypesOf?type=TheType&page=X&numberOfItems"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/subTypesOf'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #array>
	| model pageNumber numberOfItems class result |
	pageNumber := (aRequest queryOrFormParam: #page ifAbsent: [ 0 ])
		              asInteger.
	numberOfItems := (aRequest
		                  queryOrFormParam: #numberOfItems
		                  ifAbsent: [ 15 ]) asInteger.
	class := self class environment
		         at: (aRequest
				          queryOrFormParam: #type
				          ifAbsent: [ ^ MROutput json value: TeaResponse notFound ])
				         asSymbol
		         ifAbsent: [ ^ MROutput json value: TeaResponse notFound ].

	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	result := Dictionary new.
	result at: #size put: (model allWithSubTypesOf: class) size.
	result
		at: #data
		put: ((model allWithSubTypesOf: class) asOrderedCollection
				 copyFrom: numberOfItems * pageNumber + 1
				 to: numberOfItems * (pageNumber + 1)).
	^ MROutput json value: (TeaResponse ok body: result)
]

{ #category : #api }
MRAPIModel class >> summary: aRequest [

	"return the summary of a model"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/summary'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json
	schema: #array>
	| model |
	model := self retrieveModel: aRequest.
	^ MROutput json value: (TeaResponse ok body: model webSummary)
]
