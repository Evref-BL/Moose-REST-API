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
		'rootClass',
		'apiBuilder'
	],
	#category : #'Moose-REST-API-Generator'
}

{ #category : #generate }
MRGenerator >> apiClassBuilderName [

	^ self prefix , 'VersionedRESTAPIBuilder'
]

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

	self withRootAPI
		ifTrue: [ self generateRootAPI ]
		ifFalse: [ rootClass := MRAPI ].
	self generateAPIBuilder.

	(self model metamodel classes reject: [ :aFM3Class | 
		 aFM3Class allSuperclasses anySatisfy: [ :sup | 
			 sup fullName = #'Moose.Group' ] ]) do: [ :aFM3Class | 
		self visitClass: aFM3Class ]
]

{ #category : #generate }
MRGenerator >> generateAPIBuilder [

	apiBuilder := (TLVersionedRESTAPIBuilder << self apiClassBuilderName)
		              package: self packageName;
		              install.
	apiBuilder compile: ('allPragmas
	
	^ super allPragmas select: [ :pragma | 
	  pragma methodClass instanceSide = {rootAPIClassName} or: [ 
		  pragma methodClass instanceSide inheritsFrom: {rootAPIClassName} ] ]' 
			 format:
			 (Dictionary with: #rootAPIClassName -> self rootAPIClassName))
]

{ #category : #generate }
MRGenerator >> generateAllMethodFor: aClass basedOn: aFM3Class [

	aClass class compile: ('all: aRequest
	
	"An endpoint to access all {conceptName}"

	<REST_API: ''GET'' versions: #( ''v1'' ) pattern: ''model/{modelName}/{pathName}''>
	<OPEN_API_RESPONSE: #''200'' description: ''OK'' mediaType: #json schema: #array items: #{concreteClass}>
	^ TeaOutput json value: (TeaResponse ok body: (((MooseModel root detect: [ :aModel | aModel name = ''{modelName}'' ]) allWithType: {concreteClass}) asOrderedCollection))' format:
			 (self formatDictionaryFor: aFM3Class inModel: self model))
]

{ #category : #generate }
MRGenerator >> generateIdMethodFor: aClass basedOn: aFM3Class [

	aClass class compile: ('id: aRequest
	
	"An endpoint to access a {conceptName} using its id"

	<REST_API: ''GET'' versions: #( ''v1'' ) pattern: ''model/{modelName}/{pathName}/<mooseID>''>
	<OPEN_API_parameter: #mooseID schema: ''integer'' description: #''The mooseID of the entity (moose identification number)''>
	<OPEN_API_RESPONSE: #''200'' description: ''OK'' mediaType: #json schema: #object model: #{concreteClass}>
	| entityID |
	entityID := (aRequest at: #mooseID) asInteger.
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

	mapper for: self do: [ :mapping | mapping mapAccessors: #( mooseID '.
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

	rootClass := (Object << self rootAPIClassName)
		             package: self packageName;
		             install.
	rootClass class compile: 'reset

	<script>
	TLWebserver teapot removeAllDynamicRoutes'.
	rootClass class compile: ('initialize

	TLRESTApiURLPathBuilder withoutPrefix.
	{apiClassBuilder} buildAPI' format:
			 (Dictionary with: #apiClassBuilder -> self apiClassBuilderName)).

	rootClass class compile: 'api: aRequest

	"Return the OpenAPI documentation of the current teapot instance"

	<REST_API: ''GET'' versions: #( ''v1'' ) pattern: ''api''>
	<OPEN_API_RESPONSE: #''200'' description: ''OK'' mediaType: #json schema:
	#object>
	| creator api |
	creator := OpenAPICreator new.
	creator teapotInstance: TLWebserver teapot.
	creator version: ''3.0.0''.
	creator description: ''An API to request Moose model''.
	creator title: ''Moose API''.
	api := creator buildOpenAPI.


	^ TeaOutput json value: (TeaResponse ok body: api)'.
	rootClass class compile: 'inspect
	<script>
	TLWebserver teapot inspect'
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

{ #category : #generate }
MRGenerator >> rootAPIClassName [

	^ self prefix , 'RootAPI'
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
