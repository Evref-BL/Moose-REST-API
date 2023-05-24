Class {
	#name : #MRAPIModel,
	#superclass : #MRAPI,
	#category : #'Moose-REST-API'
}

{ #category : #api }
MRAPIModel class >> entities: aRequest [

	"Return the list of entities of the model. This endpoint is paginated using the param numberOfItems and page"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entities'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array items: #MRModelEntityBasicInformation>
	<OPEN_API_parameter: #modelID schema: 'integer' description: #'The id of the model you want to query'>
	<OPEN_API_Query_parameter: #numberOfItems schema: 'integer' description: #'The number of itemms the endpoint should return'>
	<OPEN_API_Query_parameter: #page schema: 'integer' description: #'The page number of the paginated return'>
	| model pageNumber numberOfItems |
	pageNumber := (aRequest queryOrFormParam: #page ifAbsent: [ 0 ])
		              asInteger.
	numberOfItems := (aRequest
		                  queryOrFormParam: #numberOfItems
		                  ifAbsent: [ 15 ]) asInteger.
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	^ TeaOutput json value: (TeaResponse ok body: ((model entities
				     copyFrom: numberOfItems * pageNumber + 1
				     to: numberOfItems * (pageNumber + 1)) collect: [ :each | 
				    MRModelEntityBasicInformation from: each ]))
]

{ #category : #api }
MRAPIModel class >> entitiesOfType: aRequest [

	"Search all entities using their implementation name. This endpoint is paginated using the param numberOfItems and page. You might increase the numberOfItems to see or change the page to explore more entities."

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entities/type/<type>'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array items: #MRModelEntityBasicInformation>
	<OPEN_API_parameter: #modelID schema: 'integer' description:
	#'The id of the model you want to query'>
	<OPEN_API_parameter: #type schema: 'string' description:
	#'The **implementation name** of the type such as: `FamixStClass`, `FamixJavaMethod` and so on'>
	<OPEN_API_Query_parameter: #numberOfItems schema: 'integer'
	description: #'The number of itemms the endpoint should return'>
	<OPEN_API_Query_parameter: #page schema: 'integer' description:
	#'The page number of the paginated return'>
	| model pageNumber numberOfItems type |
	pageNumber := (aRequest queryOrFormParam: #page ifAbsent: [ 0 ])
		              asInteger.
	numberOfItems := (aRequest
		                  queryOrFormParam: #numberOfItems
		                  ifAbsent: [ 15 ]) asInteger.
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	type := self class environment at: (aRequest at: #type) asSymbol.

	^ MROutput json value:
		  (TeaResponse ok body:
			   (((model allWithType: type) asOrderedCollection
				     copyFrom: numberOfItems * pageNumber + 1
				     to: numberOfItems * (pageNumber + 1)) collect: [ :each | 
				    MRModelEntityBasicInformation from: each ]))
]

{ #category : #api }
MRAPIModel class >> entity: aRequest [

	"An endpoint to access information about the entity entityID of the model modelID"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityFMID>'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#object model: #MRModelEntityBasicInformation>
	<OPEN_API_parameter: #modelID schema: 'integer' description:
	#'The id of the model you want to query'>
	<OPEN_API_parameter: #entityFMID schema: 'integer' description:
	#'The fmid of the entity (internal model identification number)'>
	| model entityID |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	entityID := (aRequest at: #entityFMID) asInteger.
	^ TeaOutput json value:
		  (TeaResponse ok body: (MRModelEntityBasicInformation from:
				    (model detect: [ :el | el mooseID = entityID ])))
]

{ #category : #api }
MRAPIModel class >> entityAttributes: aRequest [

	"Return the attributes and their value of a specific entity"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityFMID>/attributes'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array>
	<OPEN_API_parameter: #modelID schema: 'integer' description: #'The id of the model you want to query'>
	<OPEN_API_parameter: #entityFMID schema: 'integer' description: #'The fmid of the entity (internal model identification number)'>
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

	"Return the children entities of the entity with number entityFMID of the model indexed modelID"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityFMID>/children'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array>
	<OPEN_API_parameter: #modelID schema: 'integer' description: #'The id of the model you want to query'>
	<OPEN_API_parameter: #entityFMID schema: 'integer' description: #'The fmid of the entity (internal model identification number)'>
	| model entityID |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	entityID := (aRequest at: #entityFMID) asInteger.
	^ MROutput json value: (TeaResponse ok body:
			   (model detect: [ :el | el mooseID = entityID ]) children)
]

{ #category : #api }
MRAPIModel class >> entitySourceCode: aRequest [

	"Return the source code of an entity"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/entity/<entityFMID>/sourceCode'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#object model: #MRModelSourceCode>
	<OPEN_API_parameter: #modelID schema: 'integer' description:
	#'The id of the model you want to query'>
	<OPEN_API_parameter: #entityFMID schema: 'integer' description:
	#'The fmid of the entity (internal model identification number)'>
	| entity |
	entity := self retrieveEntity: aRequest.

	^ TeaOutput json value: (TeaResponse ok
			   body: (MRModelSourceCode new
					    fileName: ([ 
						     entity sourceAnchor
							     ifNotNil: [ :anchor | anchor fileName ]
							     ifNil: [ 'No link' ] ]
							     on: Error
							     do: [ 'No file Access' ]);
					    sourceCode: (entity sourceAnchor
							     ifNotNil: [ :anchor | anchor sourceText ]
							     ifNil: [ 'No available text' ]);
					    yourself);
			   yourself)
]

{ #category : #'api - tree' }
MRAPIModel class >> rootEntities: aRequest [

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/rootEntities'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array items: #MRModelEntityBasicInformation>
	<OPEN_API_parameter: #modelID schema: 'integer' description: #'The id of the model you want to query'>
	| model rootEntities |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	rootEntities := model select: [ :a | 
		                (a usesFamixTrait: TEntityMetaLevelDependency) and: [ 
			                a parents isEmpty ] ].
	^ MROutput json value:
		  (TeaResponse ok body: (rootEntities collect: [ :each | 
				    MRModelEntityBasicInformation from: each ]))
]

{ #category : #api }
MRAPIModel class >> subTypesOf: aRequest [

	"Return the subtypes of an entity"

	"model/<modelID>/subTypesOf?type=TheType&page=X&numberOfItems"

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/subTypesOf'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array>
	<OPEN_API_parameter: #modelID schema: 'integer' description: #'The id of the model you want to query'>
	<OPEN_API_Query_parameter: #numberOfItems schema: 'integer' description: #'The number of itemms the endpoint should return'>
	<OPEN_API_Query_parameter: #page schema: 'integer' description: #'The page number of the paginated return'>
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
