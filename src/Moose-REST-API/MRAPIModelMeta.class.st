Class {
	#name : #MRAPIModelMeta,
	#superclass : #MRAPI,
	#category : #'Moose-REST-API'
}

{ #category : #'as yet unclassified' }
MRAPIModelMeta class >> modelMeta: aRequest [

	"I return some meta information about a model such as its name or size."

	<REST_API: 'GET' versions: #( 'v1' ) pattern: 'model/<modelID>/meta'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#object model: #MRModelMetaInformation>
	<OPEN_API_parameter: #modelID schema: 'integer'>
	| model |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	^ TeaOutput json value:
		  (TeaResponse ok body: (MRModelMetaInformation new
				    size: model size;
				    name: model name;
				    id: (aRequest at: #modelID) asInteger;
				    yourself))
]

{ #category : #'as yet unclassified' }
MRAPIModelMeta class >> modelMetaEntityTypes: aRequest [

	"I return the kind of entities present in a model. For instance, one can know if a model is composed of classes, methods, traces, GUI information, and so on."

	<REST_API: 'GET' versions: #( 'v1' ) pattern:
	'model/<modelID>/meta/entityTypes'>
	<OPEN_API_RESPONSE: #'200' description: 'OK' mediaType: #json schema:
	#array items: #MRModelMetaClassModel>
	<OPEN_API_parameter: #modelID schema: 'integer'>
	| model types |
	model := MooseModel root at: (aRequest at: #modelID) asInteger.
	types := ((model metamodel classes reject: [ :a | 
		           a implementingClass isTrait or: [ 
			           (model allWithSubTypesOf: a implementingClass) isEmpty ] ]) 
		          sorted: #name ascending) collect: [ :fm3Class | 
		         MRModelMetaClassModel new
			         name: fm3Class name;
			         implementationName: fm3Class implementingClass name;
			         yourself ].
	^ MROutput json value: (TeaResponse ok body: types)
]
