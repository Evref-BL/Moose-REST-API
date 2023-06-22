"
This class takes as input a moose metamodel, and generate an API for this metamodel
"
Class {
	#name : #MRGenerator,
	#superclass : #Object,
	#instVars : [
		'prefix',
		'packageName',
		'model',
		'withRootAPI',
		'rootClass'
	],
	#category : #'Moose-REST-API-Generator'
}

{ #category : #accessing }
MRGenerator >> beWithRootAPI [
	withRootAPI := true
]

{ #category : #accessing }
MRGenerator >> beWithoutRootAPI [
	withRootAPI := false
]

{ #category : #accessing }
MRGenerator >> formatDictionaryFor: aFM3Class inModel: aMooseModel [

	^ { 
		  (#conceptName -> aFM3Class name).
		  (#pathName -> aFM3Class name asLowercase).
		  (#concreteClass -> aFM3Class implementingClass name).
		  (#modelName -> self model name) } asDictionary
]

{ #category : #visiting }
MRGenerator >> generate [

	"self withRootAPI
		ifTrue: [ self generateRootAPI ]
		ifFalse: [ rootClass := MRAPI ]."

	rootClass := MRAPI.
	self model metamodel classes do: [ :aFM3Class | 
		self visitClass: aFM3Class ]
]

{ #category : #generate }
MRGenerator >> generateAllMethodFor: aClass basedOn: aFM3Class [

	aClass class compile: ('all: aRequest
	
	"An endpoint to access all {conceptName} in the {modelName} model"

	<REST_API: ''GET'' versions: #( ''v1'' ) pattern: ''model/{modelName}/{pathName}''>
	<OPEN_API_RESPONSE: #''200'' description: ''OK'' mediaType: #json schema: #array items: #{concreteClass}>
	^ TeaOutput json value: (TeaResponse ok body: ((MooseModel root detect: [ :aModel | aModel name = ''{modelName}'' ]) allWithType: {concreteClass}))' format:
			 (self formatDictionaryFor: aFM3Class inModel: self model))
]

{ #category : #generate }
MRGenerator >> generateIdMethodFor: aClass basedOn: aFM3Class [

	aClass class compile: ('id: aRequest
	
	"An endpoint to access a {conceptName} in the {modelName} model using its id"

	<REST_API: ''GET'' versions: #( ''v1'' ) pattern: ''model/{modelName}/{pathName}/<entityFMID>''>
	<OPEN_API_parameter: #entityFMID schema: ''integer'' description: #''The fmid of the entity (internal model identification number)''>
	<OPEN_API_RESPONSE: #''200'' description: ''OK'' mediaType: #json schema: #object model: #{concreteClass}>
	| entityID |
	entityID := (aRequest at: #entityFMID) asInteger.
	^ TeaOutput json value: (TeaResponse ok body: ((MooseModel root detect: [ :aModel | aModel name = ''{modelName}'' ]) 
		  detect: [ :entity | entity mooseID = entityID ]))' format:
			 (self formatDictionaryFor: aFM3Class inModel: self model))
]

{ #category : #generate }
MRGenerator >> generateNeoJsonMappingBasedOn: aFM3Class [

	"this generate the method neoJsonMapping: in the implementation class"

	aFM3Class primitiveProperties.
	aFM3Class implementingClass class compile:
		(String streamContents: [ :stream | 
			 stream << 'neoJsonMapping: mapper

	mapper for: self do: [ :mapping | mapping mapInstVars: #( mooseID '.
			 aFM3Class allPrimitiveProperties
				 do: [ :property | 
					 stream
						 << '#';
						 << property name ]
				 separatedBy: [ stream << ' ' ].
			 stream << ' ). ]' ])
]

{ #category : #generate }
MRGenerator >> generateRootAPI [

	rootClass := (Object << (self prefix , 'RootAPI'))
		             package: self packageName;
		             install.
	rootClass class compile: 'reset

	<script>
	TLWebserver teapot removeAllDynamicRoutes'.
	rootClass class compile: 'initialize

	TLRESTApiURLPathBuilder withoutPrefix.
	TLRESTAPIBuilder buildAPI'
]

{ #category : #visiting }
MRGenerator >> initialize [
	super initialize.
	prefix := #MRSubAPI.
	packageName := 'Moose-REST-API-Sub'.
	withRootAPI := true
]

{ #category : #accessing }
MRGenerator >> model [

	^ model
]

{ #category : #accessing }
MRGenerator >> model: anObject [

	model := anObject
]

{ #category : #accessing }
MRGenerator >> packageName [

	^ packageName
]

{ #category : #accessing }
MRGenerator >> packageName: anObject [

	packageName := anObject
]

{ #category : #accessing }
MRGenerator >> prefix [
	^ prefix
]

{ #category : #accessing }
MRGenerator >> prefix: anObject [

	prefix := anObject
]

{ #category : #visiting }
MRGenerator >> visitClass: aFM3Class [

	| class |
	class := (rootClass << (self prefix , aFM3Class name))
		         package: self packageName;
		         install.

	self generateAllMethodFor: class basedOn: aFM3Class.
	self generateIdMethodFor: class basedOn: aFM3Class.
	self generateNeoJsonMappingBasedOn: aFM3Class
]

{ #category : #accessing }
MRGenerator >> withRootAPI [

	^ withRootAPI
]

{ #category : #accessing }
MRGenerator >> withRootAPI: anObject [

	withRootAPI := anObject
]
