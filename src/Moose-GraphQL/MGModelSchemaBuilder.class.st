"
I build a GraphQL schema (GQLSchema) whose object types are the concepts of ONE Moose model, i.e. the entity types of its metamodel, instead of the generic Entity/MetaClass/Model/Property/Relation types of MGSchema.

	MGModelSchemaBuilder buildFor: aMooseModel

Concepts (see MGConcept):
- root concepts: every concrete FM3 class having at least one instance in the model (built-in and primitive classes excluded). Only they get root fields on Query: a plural list field (e.g. methods(take: Int): [Method!]!) and a singular by-id field (e.g. method(id: ID!): Method);
- relation targets: for each relation property, the concrete classes having instances that conform to its declared FM3 type (subclass, or class using the trait) are computed:
	- none: the relation can only be empty, so no field is generated for it (and no type for its target);
	- exactly one (e.g. TMethod -> Method): the relation is typed with that root concept;
	- two or more (e.g. TWithComments -> Class, Method): the relation is typed with a hidden helper concept generated for the declared trait / abstract class itself (no root field). Helper types follow the same rules for their own relations, transitively.

Naming: the FM3 short name (e.g. Method), or the sanitized fullName (e.g. FamixTest1Entities_Entity) on collisions or reserved names.

Each object type (root or helper) has id: ID!, name: String, type: String (concrete meta-class name), one field per primitive property (String, Boolean, the custom Number scalar, or String for anything else; [T] when multivalued) and one field per exposed relation (Target, or [Target!]! with take: Int when multivalued). Derived properties are included. Every resolver is error-proof (MGSafe) and answers nil / empty on failure.

When the model has no entity to expose (no root concept), #build signals MGEmptyModelError ('Model <name> has no entity to expose') instead of producing an invalid schema.

Resolvers expect an MGRegistry as execution context (see MGRegistry class>>forModel:).
"
Class {
	#name : 'MGModelSchemaBuilder',
	#superclass : 'Object',
	#instVars : [
		'model',
		'registry',
		'concreteClasses',
		'concepts',
		'targets',
		'builder',
		'objectKinds',
		'supertypeSets'
	],
	#category : 'Moose-GraphQL-Schema',
	#package : 'Moose-GraphQL',
	#tag : 'Schema'
}

{ #category : 'building' }
MGModelSchemaBuilder class >> buildFor: aMooseModel [
	"Answer a new GQLSchema whose object types are the concepts of aMooseModel"

	^ (self on: aMooseModel) build
]

{ #category : 'scalars' }
MGModelSchemaBuilder class >> coerceTemporal: aValue as: aScalarName [
	"Input value of the temporal scalar named aScalarName: aValue when it already is of that kind, the parsed Pharo value when it is a valid ISO 8601 String, nil when not acceptable (never raises)"

	^ MGSafe
		  do: [
				  (MGTemporalFormat scalarNameOf: aValue) = aScalarName
					  ifTrue: [ aValue ]
					  ifFalse: [ MGTemporalFormat parse: aValue as: aScalarName ] ]
		  default: nil
]

{ #category : 'naming' }
MGModelSchemaBuilder class >> genericFieldNames [
	"Names of the generic fields of every concept type, declared by the MooseEntity interface (see #defineGenericFieldsOn:)"

	^ #( 'id' 'name' 'type' 'types' 'container' 'containers' 'children' 'childrenCount' 'ancestors' )
]

{ #category : 'object properties' }
MGModelSchemaBuilder class >> objectSampleSize [
	"Number of non-nil values of an Object-typed property sampled to infer its GraphQL type"

	^ 200
]

{ #category : 'object properties' }
MGModelSchemaBuilder class >> objectScanLimit [
	"Maximum number of instances read to infer the GraphQL type of an Object-typed property"

	^ 10000
]

{ #category : 'instance creation' }
MGModelSchemaBuilder class >> on: aMooseModel [

	^ self new setModel: aMooseModel
]

{ #category : 'naming' }
MGModelSchemaBuilder class >> renamedGenericFieldNames [
	"Generic field names that an FM3 property exposed as is would clash with: such a property is exposed with a trailing underscore (e.g. id_, type_). A property called name is not exposed, the generic name field answers it"

	^ self genericFieldNames copyWithout: 'name'
]

{ #category : 'naming' }
MGModelSchemaBuilder class >> reservedTypeNames [
	"Names that a concept type may not take (besides names starting with __)"

	^ #( 'Query' 'String' 'Int' 'Float' 'Boolean' 'ID' 'Number' 'MooseEntity' )
	  , MGTemporalFormat temporalScalarNames
]

{ #category : 'scalars' }
MGModelSchemaBuilder class >> serializeNumber: aValue [
	"Output value of the Number scalar: Integers as is, other finite numbers as Floats, nil otherwise"

	^ MGSafe
		  do: [
			  aValue isInteger
				  ifTrue: [ aValue ]
				  ifFalse: [
					  aValue isNumber ifTrue: [
						  aValue asFloat in: [ :f | f isFinite ifTrue: [ f ] ] ] ] ]
		  default: nil
]

{ #category : 'scalars' }
MGModelSchemaBuilder class >> serializeTemporal: aValue as: aScalarName [
	"Output value of the temporal scalar named aScalarName: the ISO 8601 String of aValue when it is of that kind, aValue itself when it is a String valid for that scalar, nil otherwise (never raises)"

	^ MGSafe
		  do: [
				  (MGTemporalFormat scalarNameOf: aValue) = aScalarName
					  ifTrue: [ MGTemporalFormat print: aValue ]
					  ifFalse: [
							  (aValue isString and: [
								   (MGTemporalFormat parse: aValue as: aScalarName) notNil ])
								  ifTrue: [ aValue asString ] ] ]
		  default: nil
]

{ #category : 'scalars' }
MGModelSchemaBuilder class >> temporalScalarNameForTypeNamed: aTypeName [
	"Temporal scalar standing for an explicitly typed FM3 property: Date, Time, DateTime (for DateAndTime, DateTime and Timestamp) or Duration; nil for any other type name"

	(#( 'DateAndTime' 'DateTime' 'Timestamp' ) includes: aTypeName)
		ifTrue: [ ^ 'DateTime' ].
	^ (#( 'Date' 'Time' 'Duration' ) includes: aTypeName) ifTrue: [
		  aTypeName asString ]
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> addHelperConceptFor: anFM3Type [
	"Register the hidden helper concept of anFM3Type, the declared type of a relation satisfied by several concrete classes of the model"

	^ concepts at: anFM3Type put: (MGConcept
			   helperType: anFM3Type
			   conformingClasses: (self concreteClassesConformingTo: anFM3Type))
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> addRootConceptFor: anFM3Class [
	"Register the root concept of anFM3Class, a concrete class having instances in the model. Its root fields answer the instances of exactly anFM3Class (not of its subclasses)"

	^ concepts at: anFM3Class put: (MGConcept
			   rootType: anFM3Class
			   conformingClasses: { anFM3Class })
]

{ #category : 'naming' }
MGModelSchemaBuilder >> assignRootFieldNames [
	"Singular lowerFirst by-id fields first (e.g. method), then plural lowerFirst list fields (e.g. methods), all unique and distinct from rootEntities; root concepts only"

	| used roots |
	used := Set with: 'rootEntities'.
	roots := self rootConcepts.
	roots do: [ :each |
			each byIdFieldName: (self
					 uniqueName: each typeName uncapitalized
					 among: used
					 alternative: 'ById') ].
	roots do: [ :each |
			each listFieldName: (self
					 uniqueName: (self pluralOf: each typeName) uncapitalized
					 among: used
					 alternative: 'List') ]
]

{ #category : 'naming' }
MGModelSchemaBuilder >> assignTypeNames [
	"Short FM3 names, or sanitized fullNames on collisions and reserved names; unique in the schema"

	| byShortName used |
	byShortName := self concepts groupedBy: [ :each | each shortName ].
	used := Set withAll: self class reservedTypeNames.
	self concepts do: [ :each |
		each typeName: (self
				 uniqueName: (self preferredTypeNameOf: each among: byShortName)
				 among: used
				 alternative: '') ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> build [
	"Answer the GQLSchema exposing the concepts of the model; signal MGEmptyModelError when the model has no entity to expose"

	self collectConcepts.
	self rootConcepts ifEmpty: [
		^ MGEmptyModelError signalForModelNamed:
			  (registry modelNameOf: model) ].
	self
		assignTypeNames;
		assignRootFieldNames;
		computeFields.
	builder := GQLSchemaBuilder new.
	self
		defineNumberScalar;
		defineTemporalScalars;
		defineMooseEntityInterface;
		defineQuery;
		defineConceptTypes.
	builder typeResolver: [ :value :context |
		self runtimeTypeNameOf: value in: context ].
	builder query: 'Query'.
	^ builder build
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> collectConcepts [
	"Root concepts are the concrete classes having instances; hidden helper concepts are added (transitively) for the declared types of polymorphic relations"

	| pending |
	concreteClasses := self concreteClassesOfModel.
	pending := OrderedCollection new.
	concreteClasses do: [ :each |
		pending add: (self addRootConceptFor: each) ].
	[ pending isEmpty ] whileFalse: [
		pending addAll: (self newTargetConceptsOf: pending removeFirst) ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> computeFields [
	"Compute the field specs of every concept (see #fieldSpecsOf:)"

	self concepts do: [ :each | each fields: (self fieldSpecsOf: each) ]
]

{ #category : 'accessing' }
MGModelSchemaBuilder >> concepts [
	"The concepts of the model, sorted by FM3 fullName (available after #collectConcepts)"

	^ concepts values sorted: [ :a :b | a fullName <= b fullName ]
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> concreteClassesConformingTo: anFM3Type [
	"Concrete classes of the model (having instances) conforming to anFM3Type, cached per type"

	^ targets at: anFM3Type ifAbsentPut: [
			  concreteClasses select: [ :each |
				  self isClass: each conformingTo: anFM3Type ] ]
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> concreteClassesOfModel [
	"FM3 classes having at least one instance in the model (built-in and primitive classes excluded), sorted by fullName"

	^ MGSafe
		  do: [
			  ((registry instancesIndexOf: model) keys select: [ :each |
				   self isConceptClass: each ]) sorted: [ :a :b |
				  (self fullNameOf: a) <= (self fullNameOf: b) ] ]
		  default: #(  )
]

{ #category : 'scalars' }
MGModelSchemaBuilder >> converterFor: aScalarName [
	"A block converting a raw property value into a value of aScalarName (nil when not convertible)"

	aScalarName = 'Boolean' ifTrue: [
		^ [ :value |
		  (value == true or: [ value == false ]) ifTrue: [ value ] ] ].
	aScalarName = 'Number' ifTrue: [
		^ [ :value | value isNumber ifTrue: [ value ] ] ].
	(MGTemporalFormat temporalScalarNames includes: aScalarName) ifTrue: [
			^ [ :value |
			  (MGTemporalFormat scalarNameOf: value) = aScalarName ifTrue: [
				  value ] ] ].
	^ [ :value |
		  value isString
			  ifTrue: [ value asString ]
			  ifFalse: [ MGSafe printValue: value ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineConceptTypes [
	self concepts do: [ :each |
		builder
			object: each typeName
			description: each description
			implements: #( 'MooseEntity' )
			fields: [ :object | self defineFieldsOf: each on: object ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineFieldsOf: aConcept on: anObjectTypeBuilder [
	"Generic MooseEntity fields first, then the fields specified for aConcept (see #fieldSpecsOf:)"

	self defineGenericFieldsOn: anObjectTypeBuilder.
	self defineSpecFields: aConcept on: anObjectTypeBuilder
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineGenericFieldsOn: anObjectTypeBuilder [
	"Fields of the MooseEntity interface, shared by every concept type: identity (id, name, type), supertype names (types) and containment (container, containers, children, childrenCount, ancestors).
	Entity results are restricted to the entities having a concept type (see #exposableEntity:)"

	self defineIdentityFieldsOn: anObjectTypeBuilder.
	anObjectTypeBuilder
		field: 'types'
		type: '[String!]!'
		description: 'Names of the entity meta-class and of all its supertypes (superclasses and traits).'
		resolve: [ :entity :args :context |
			(self registryFrom: context) supertypeNamesOf: entity ].
	anObjectTypeBuilder
		field: 'container'
		type: 'MooseEntity'
		description: 'Direct container of the entity (the first one when it has several), or null.'
		resolve: [ :entity :args :context |
			(self exposable: ((self registryFrom: context) containersOf: entity))
				ifEmpty: [ nil ]
				ifNotEmpty: [ :containers | containers first ] ].
	anObjectTypeBuilder
		field: 'containers'
		type: '[MooseEntity!]!'
		description: 'All direct containers of the entity.'
		resolve: [ :entity :args :context |
			self exposable: ((self registryFrom: context) containersOf: entity) ].
	anObjectTypeBuilder
		field: 'children'
		type: '[MooseEntity!]!'
		description: 'Entities directly contained by this entity (at most take, default ' , MGSchema defaultTake printString , ').'
		args: { ('take' -> 'Int') }
		resolve: [ :entity :args :context |
			self exposable: ((self registryFrom: context)
					 childrenOf: entity
					 take: (MGSchema arg: 'take' in: args)) ].
	anObjectTypeBuilder
		field: 'childrenCount'
		type: 'Int'
		description: 'Number of entities directly contained by this entity.'
		resolve: [ :entity :args :context |
			(self registryFrom: context) childrenCountOf: entity ].
	anObjectTypeBuilder
		field: 'ancestors'
		type: '[MooseEntity!]!'
		description: 'Containment chain of the entity, nearest container first (at most take, default ' , MGSchema defaultTake printString , ').'
		args: { ('take' -> 'Int') }
		resolve: [ :entity :args :context |
			self exposable: ((self registryFrom: context)
					 ancestorsOf: entity
					 take: (MGSchema arg: 'take' in: args)) ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineIdentityFieldsOn: anObjectTypeBuilder [
	anObjectTypeBuilder
		field: 'id'
		type: 'ID!'
		description: 'Opaque id (<modelId>:<mooseID>).'
		resolve: [ :entity :args :context |
			(self registryFrom: context) idOfEntity: entity ].
	anObjectTypeBuilder
		field: 'name'
		type: 'String'
		description: 'Entity name, or its mooseName when it has no name.'
		resolve: [ :entity :args :context |
			(self registryFrom: context) nameOfEntity: entity ].
	anObjectTypeBuilder
		field: 'type'
		type: 'String'
		description: 'Name of the concrete meta-class of the entity (e.g. Method).'
		resolve: [ :entity :args :context |
			(self registryFrom: context) typeOfEntity: entity ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineMooseEntityInterface [
	"The MooseEntity interface, implemented by every concept type (see #defineGenericFieldsOn:)"

	builder
		interface: 'MooseEntity'
		description: 'Any entity of the Moose model ' , (registry modelNameOf: model) asString
			, ': every concept type implements it with the identity, supertype names and containment fields.'
		fields: [ :interface | self defineGenericFieldsOn: interface ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineNumberScalar [
	"Number scalar used for FM3 Number properties: Integers and Floats are serialized as is"

	| type |
	type := GQLScalarType
		        name: 'Number'
		        description:
		        'A Moose number: an Int or a Float, serialized as is.'
		        serialize: [ :value | self class serializeNumber: value ]
		        coerce: [ :value | value ].
	type coerceBlock: [ :value |
		(value isNumber and: [ value isFloat not or: [ value isFinite ] ])
			ifTrue: [ value ]
			ifFalse: [ type coercionError: value ] ].
	builder scalar: type
]

{ #category : 'building' }
MGModelSchemaBuilder >> definePrimitiveField: aName for: anFM3Property scalar: aScalarName on: anObjectTypeBuilder [
	"Field aName of scalar type aScalarName (a list of it when anFM3Property is multivalued) exposing anFM3Property"

	| converter |
	converter := self converterFor: aScalarName.
	(self isMultivalued: anFM3Property)
		ifTrue: [
				anObjectTypeBuilder
					field: aName
					type: '[' , aScalarName , ']'
					description: (self descriptionOf: anFM3Property)
					resolve: [ :entity :args :context |
						self valuesOf: anFM3Property in: entity converter: converter ] ]
		ifFalse: [
				anObjectTypeBuilder
					field: aName
					type: aScalarName
					description: (self descriptionOf: anFM3Property)
					resolve: [ :entity :args :context |
						self valueOf: anFM3Property in: entity converter: converter ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineQuery [

	builder
		object: 'Query'
		description:
			'Entry points to explore the concepts of the Moose model '
			, (registry modelNameOf: model) asString , '.'
		fields: [ :object |
				object
					field: 'rootEntities'
					type: '[MooseEntity!]!'
					description: 'Entities of the model without container (at most take, default ' , MGSchema defaultTake printString , ').'
					args: { ('take' -> 'Int') }
					resolve: [ :source :args :context |
						self exposable: ((self registryFrom: context)
								 rootEntitiesOf: model
								 take: (MGSchema arg: 'take' in: args)) ].
				self rootConcepts do: [ :each |
					self defineRootFieldsOf: each on: object ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineRelationField: aFieldSpec on: anObjectTypeBuilder [
	"Relation field of aFieldSpec: a list bounded by a take argument when multivalued, the first entity (or null) otherwise"

	aFieldSpec hasTakeArgument
		ifTrue: [
			anObjectTypeBuilder
				field: aFieldSpec name
				type: aFieldSpec typeString
				description: (self descriptionOf: aFieldSpec property)
				args: { ('take' -> 'Int') }
				resolve: [ :entity :args :context |
					MGSafe
						take: (MGSchema arg: 'take' in: args)
						from: (self entitiesOfField: aFieldSpec in: entity) ] ]
		ifFalse: [
			anObjectTypeBuilder
				field: aFieldSpec name
				type: aFieldSpec typeString
				description: (self descriptionOf: aFieldSpec property)
				resolve: [ :entity :args :context |
					(self entitiesOfField: aFieldSpec in: entity)
						ifEmpty: [ nil ]
						ifNotEmpty: [ :entities | entities first ] ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineRootFieldsOf: aConcept on: anObjectTypeBuilder [
	anObjectTypeBuilder
		field: aConcept listFieldName
		type: '[' , aConcept typeName , '!]!'
		description: 'Entities of the model that are ' , aConcept typeName , ' (at most take, default ' , MGSchema defaultTake printString , ').'
		args: { ('take' -> 'Int') }
		resolve: [ :source :args :context |
			(self registryFrom: context)
				instancesOfAll: aConcept conformingClasses
				model: model
				take: (MGSchema arg: 'take' in: args) ].
	anObjectTypeBuilder
		field: aConcept byIdFieldName
		type: aConcept typeName
		description: 'A ' , aConcept typeName , ' by id (<modelId>:<mooseID>), null when unknown or of another type.'
		args: { ('id' -> 'ID!') }
		resolve: [ :source :args :context |
			(self registryFrom: context)
				entityAt: (MGSchema arg: 'id' in: args)
				ofAnyOf: aConcept conformingClasses ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineSpecFields: aConcept on: anObjectTypeBuilder [
	"Define the fields specified by the field specs of aConcept (see #computeFields)"

	aConcept fields do: [ :spec |
		spec isScalar
			ifTrue: [
				self
					definePrimitiveField: spec name
					for: spec property
					scalar: spec scalarName
					on: anObjectTypeBuilder ]
			ifFalse: [ self defineRelationField: spec on: anObjectTypeBuilder ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineTemporalScalar: aName description: aDescription [
	"Temporal scalar aName (see MGTemporalFormat): serialized as an ISO 8601 String, input accepted as an ISO 8601 String"

	| type |
	type := GQLScalarType
		        name: aName
		        description: aDescription
		        serialize: [ :value |
		        self class serializeTemporal: value as: aName ]
		        coerce: [ :value | value ].
	type coerceBlock: [ :value |
			(self class coerceTemporal: value as: aName) ifNil: [
				type coercionError: value ] ].
	builder scalar: type
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineTemporalScalars [
	"Date, Time, DateTime and Duration scalars used for temporal properties (see MGTemporalFormat)"

	self
		defineTemporalScalar: 'Date'
		description:
		'A calendar date in ISO 8601 / RFC 3339 full-date form: YYYY-MM-DD (e.g. 2017-07-04).'.
	self
		defineTemporalScalar: 'Time'
		description:
		'A time of day in ISO 8601 / RFC 3339 partial-time form, 24h: hh:mm:ss with an optional fraction of at most 3 digits (e.g. 04:05:06 or 16:05:06.25). Input also accepts hh:mm and longer fractions.'.
	self
		defineTemporalScalar: 'DateTime'
		description:
		'A date and time in ISO 8601 / RFC 3339 date-time form keeping its UTC offset: YYYY-MM-DDThh:mm:ss[.fff]±hh:mm (e.g. 2017-07-04T04:05:06+00:00). Input also accepts a space or t separator, the Z/z, ±hh:mm and ±hhmm offsets, and no offset meaning UTC.'.
	self
		defineTemporalScalar: 'Duration'
		description:
		'A duration in ISO 8601 form using days, hours, minutes and seconds, optionally negative (e.g. PT0S, PT2M5S, P1DT2H3M4.5S, -PT5S). Input also accepts weeks (W); years and months are rejected.'
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> descriptionOf: anFM3Property [
	"FM3 comment of anFM3Property when present, a generated description otherwise"

	| comment |
	comment := MGSafe
		           do: [ anFM3Property comment ifNil: [ '' ] ifNotNil: [ :text | text asString trimBoth ] ]
		           default: ''.
	^ String streamContents: [ :s |
		  comment
			  ifEmpty: [
				  s
					  nextPutAll: 'Property ';
					  nextPutAll: (MGSafe do: [ anFM3Property name asString ] default: '?');
					  nextPutAll: ' of type ';
					  nextPutAll: (MGSafe do: [ anFM3Property type name asString ] default: '?');
					  nextPut: $. ]
			  ifNotEmpty: [ s nextPutAll: comment ].
		  (MGSafe do: [ anFM3Property isDerived == true ] default: false)
			  ifTrue: [ s nextPutAll: ' (derived)' ] ]
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> entitiesOf: anFM3Property in: anEntity [
	"Entities held by the relation anFM3Property of anEntity (empty on error)"

	^ MGSafe entitiesIn: (self rawValueOf: anFM3Property in: anEntity)
]

{ #category : 'building' }
MGModelSchemaBuilder >> entitiesOfField: aFieldSpec in: anEntity [
	"Entities held by the relation of aFieldSpec in anEntity, restricted to the exposable ones when the field is typed with MooseEntity (see #exposable:)"

	| entities |
	entities := self entitiesOf: aFieldSpec property in: anEntity.
	^ aFieldSpec target
		  ifNil: [ self exposable: entities ]
		  ifNotNil: [ entities ]
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> exposable: aCollection [
	"The entities of aCollection having a concept object type (see #exposableEntity:), as an Array"

	^ (aCollection ifNil: [ #(  ) ]) asArray select: [ :each |
		  self exposableEntity: each ]
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> exposableEntity: anEntity [
	"True when anEntity has a concept object type (see #runtimeTypeNameOf:in:)"

	^ (self runtimeTypeNameOf: anEntity in: registry) notNil
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> exposedRelationPropertiesOf: aConcept [
	"Relation properties of aConcept that may hold entities of the model, sorted by name"

	^ (self relationPropertiesOf: aConcept) select: [ :each |
		  self isExposedRelation: each ]
]

{ #category : 'naming' }
MGModelSchemaBuilder >> fieldNameFor: anFM3Property among: usedNames [
	"GraphQL field name of anFM3Property (generic field names but name get a trailing underscore, see class>>#renamedGenericFieldNames), or nil when already used"

	| name |
	name := self graphQLNameFrom: (MGSafe do: [ anFM3Property name asString ] default: '').
	(self class renamedGenericFieldNames includes: name) ifTrue: [ name := name , '_' ].
	(usedNames includes: name) ifTrue: [ ^ nil ].
	usedNames add: name.
	^ name
]

{ #category : 'building' }
MGModelSchemaBuilder >> fieldSpecsOf: aConcept [
	"Field specs (MGConceptField) of aConcept by field name: primitive properties first, then exposed relations; names unique and distinct from the generic field names (see #fieldNameFor:among:)"

	| used specs |
	used := Set withAll: self class genericFieldNames.
	specs := OrderedDictionary new.
	(self primitivePropertiesOf: aConcept) do: [ :property |
		(self fieldNameFor: property among: used) ifNotNil: [ :name |
			specs at: name put: (MGConceptField
					 scalarNamed: name
					 property: property
					 scalarName: (self scalarNameFor: property in: aConcept)
					 multivalued: (self isMultivalued: property)) ] ].
	(self exposedRelationPropertiesOf: aConcept) do: [ :property |
		(self fieldNameFor: property among: used) ifNotNil: [ :name |
			specs at: name put: (MGConceptField
					 relationNamed: name
					 property: property
					 target: (self targetConceptFor: property type)
					 multivalued: (self isMultivalued: property)) ] ].
	^ specs
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> fullNameOf: anFM3Type [
	^ MGSafe do: [ anFM3Type fullName asString ] default: ''
]

{ #category : 'naming' }
MGModelSchemaBuilder >> graphQLNameFrom: aString [
	"A valid GraphQL name ([_A-Za-z][_0-9A-Za-z]*) derived from aString: dots and colons become underscores, other invalid characters are dropped
	(e.g. Famix-Test1-Entities.Entity -> FamixTest1Entities_Entity)"

	| name |
	name := String streamContents: [ :s |
		        aString do: [ :char |
			        (self isGraphQLNameCharacter: char)
				        ifTrue: [ s nextPut: char ]
				        ifFalse: [ (char = $. or: [ char = $: ]) ifTrue: [ s nextPut: $_ ] ] ] ].
	(name isEmpty or: [ name first isDigit ]) ifTrue: [ name := 'T' , name ].
	(name beginsWith: '__') ifTrue: [ name := 'T' , name ].
	^ name
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> inferObjectScalarNameOf: anFM3Property [
	"Scalar exposing the Object-typed anFM3Property, inferred from a sample of its values (see #objectValueKindsOf:):
	no value or only entities -> nil (the property stays a relation);
	only Dates, Times, DateAndTimes or Durations -> Date, Time, DateTime or Duration;
	only Strings, Booleans or Numbers -> String, Boolean or Number;
	anything else, including entities mixed with other values -> String.
	Derived properties are not sampled (they may be expensive) and stay relations."

	| kinds |
	(MGSafe do: [ anFM3Property isDerived == true ] default: true)
		ifTrue: [ ^ nil ].
	kinds := MGSafe
		         do: [ self objectValueKindsOf: anFM3Property ]
		         default: Set new.
	kinds ifEmpty: [ ^ nil ].
	kinds size = 1 ifFalse: [ ^ 'String' ].
	kinds anyOne = #entity ifTrue: [ ^ nil ].
	kinds anyOne = #other ifTrue: [ ^ 'String' ].
	^ kinds anyOne
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> inferObjectScalarNameOf: anFM3Property in: aConcept [
	"The inference does not depend on aConcept: see #inferObjectScalarNameOf:"

	^ self inferObjectScalarNameOf: anFM3Property
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> isClass: anFM3Class conformingTo: anFM3Type [
	"True when anFM3Type is the built-in Object type (every class conforms to it), or when it is not built-in and is anFM3Class or one of its supertypes (superclasses and traits, see #supertypeSetOf:)"

	^ MGSafe
		  do: [
			  (anFM3Type isKindOf: FM3Object) or: [
				  (registry isBuiltInType: anFM3Type) not and: [
					  (self supertypeSetOf: anFM3Class) includes: anFM3Type ] ] ]
		  default: false
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> isConceptClass: anFM3Class [
	^ MGSafe
		  do: [ anFM3Class isBuiltIn not and: [ anFM3Class isPrimitive not ] ]
		  default: false
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> isExplicitTemporalProperty: anFM3Property [
	"True when anFM3Property is explicitly typed Date, DateAndTime, DateTime, Timestamp, Time or Duration and no concrete class of the model conforms to that type (so it holds Pharo temporal values, not entities)"

	^ MGSafe
		  do: [
				  (self isObjectProperty: anFM3Property) not and: [
						  (self class temporalScalarNameForTypeNamed:
							   anFM3Property type name asString) notNil and: [
							  (self concreteClassesConformingTo: anFM3Property type)
								  isEmpty ] ] ]
		  default: false
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> isExposedRelation: anFM3Property [
	"True when at least one concrete class having instances in the model conforms to the declared type of anFM3Property; other relations can only be empty and are not exposed"

	^ MGSafe
		  do: [
		  (self concreteClassesConformingTo: anFM3Property type) notEmpty ]
		  default: false
]

{ #category : 'naming' }
MGModelSchemaBuilder >> isGraphQLNameCharacter: aCharacter [
	^ aCharacter = $_ or: [
		  (aCharacter between: $a and: $z) or: [
			  (aCharacter between: $A and: $Z) or: [ aCharacter between: $0 and: $9 ] ] ]
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> isMultivalued: anFM3Property [
	^ MGSafe do: [ anFM3Property isMultivalued == true ] default: false
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> isObjectProperty: anFM3Property [
	"True when anFM3Property is typed Object (FM3Object), so its values may be entities or plain Pharo objects"

	^ MGSafe
		  do: [ anFM3Property type isKindOf: FM3Object ]
		  default: false
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> isRelationProperty: anFM3Property [
	"True when anFM3Property is typed by a non-primitive FM3 type, except explicit temporal types (see #isExplicitTemporalProperty:)"

	^ MGSafe
		  do: [
				  anFM3Property type notNil and: [
						  anFM3Property type isPrimitive not and: [
							  (self isExplicitTemporalProperty: anFM3Property) not ] ] ]
		  default: false
]

{ #category : 'naming' }
MGModelSchemaBuilder >> isReservedTypeName: aString [
	^ (self class reservedTypeNames includes: aString) or: [
		  aString beginsWith: '__' ]
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> isScalarObjectProperty: anFM3Property in: aConcept [
	"True when anFM3Property is typed Object and its sampled values are not only entities (see #inferObjectScalarNameOf:), so it is exposed as a scalar field instead of a relation"

	^ (self isObjectProperty: anFM3Property) and: [
		  (self objectScalarNameOf: anFM3Property) notNil ]
]

{ #category : 'accessing' }
MGModelSchemaBuilder >> model [
	^ model
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> newTargetConceptsOf: aConcept [
	"Helper concepts created for the polymorphic relation targets of aConcept that were not known yet"

	^ Array streamContents: [ :stream |
			  (self exposedRelationPropertiesOf: aConcept) do: [ :property |
					  | target |
					  target := self targetTypeFor: property type.
					  (concepts includesKey: target) ifFalse: [
						  stream nextPut: (self addHelperConceptFor: target) ] ] ]
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> objectKindOf: aValue [
	"Kind of a value of an Object-typed property: #entity for Moose entities, the temporal scalar name for dates, times and durations (see MGTemporalFormat), String, Boolean or Number for those values, #other otherwise (collections included)"

	(MGSafe isEntity: aValue) ifTrue: [ ^ #entity ].
	(MGTemporalFormat scalarNameOf: aValue) ifNotNil: [ :scalarName |
		^ scalarName ].
	^ MGSafe
		  do: [
				  aValue isString
					  ifTrue: [ 'String' ]
					  ifFalse: [
							  (aValue == true or: [ aValue == false ])
								  ifTrue: [ 'Boolean' ]
								  ifFalse: [
										  aValue isNumber
											  ifTrue: [ 'Number' ]
											  ifFalse: [ #other ] ] ] ]
		  default: #other
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> objectScalarNameOf: anFM3Property [
	"Scalar inferred for the Object-typed anFM3Property, nil when it stays a relation; computed once per property (see #inferObjectScalarNameOf:)"

	^ objectKinds
		  at: anFM3Property
		  ifAbsentPut: [ self inferObjectScalarNameOf: anFM3Property ]
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> objectScalarNameOf: anFM3Property in: aConcept [
	"The inference does not depend on aConcept: see #objectScalarNameOf:"

	^ self objectScalarNameOf: anFM3Property
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> objectValueKindsOf: anFM3Property [
	"Kinds of the sampled values of anFM3Property over the instances of the classes declaring it (see #sampledClassesOf: and #objectValueKindsOf:inClasses:)"

	^ self
		  objectValueKindsOf: anFM3Property
		  inClasses: (self sampledClassesOf: anFM3Property)
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> objectValueKindsOf: anFM3Property in: aConcept [
	"The inference does not depend on aConcept: see #objectValueKindsOf:"

	^ self objectValueKindsOf: anFM3Property
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> objectValueKindsOf: anFM3Property inClasses: someFM3Classes [
	"Kinds (see #objectKindOf:) of the non-nil values of anFM3Property over the instances of someFM3Classes, iterated in order.
	Sampling stops after #objectSampleSize values, #objectScanLimit instances, or as soon as the kinds are decisive (mixed or other)"

	| kinds sampled scanned |
	kinds := Set new.
	sampled := 0.
	scanned := 0.
	someFM3Classes do: [ :each |
			(registry instancesOf: each model: model) do: [ :entity |
					(self objectValuesOf: anFM3Property in: entity) do: [ :value |
							kinds add: (self objectKindOf: value).
							sampled := sampled + 1 ].
					scanned := scanned + 1.
					(sampled >= self class objectSampleSize or: [
							 scanned >= self class objectScanLimit or: [
								 kinds size > 1 or: [ kinds includes: #other ] ] ]) ifTrue: [
						^ kinds ] ] ].
	^ kinds
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> objectValuesOf: anFM3Property in: anEntity [
	"Non-nil values of anFM3Property for anEntity: the elements (at most MGSchema maxTake) of a multivalued property, the value itself otherwise (a collection held by a single-valued property is one value)"

	| value values |
	value := (self rawValueOf: anFM3Property in: anEntity) ifNil: [
		         ^ #(  ) ].
	values := ((self isMultivalued: anFM3Property) and: [
		           MGSafe isCollectionLike: value ])
		          ifTrue: [ MGSafe take: MGSchema maxTake from: value ]
		          ifFalse: [ { value } ].
	^ values reject: [ :each | each isNil ]
]

{ #category : 'naming' }
MGModelSchemaBuilder >> pluralOf: aName [
	"Simple English plural: s/x/ch/sh -> +es, consonant+y -> ies, otherwise +s"

	(#( 's' 'x' 'ch' 'sh' ) anySatisfy: [ :suffix | aName endsWith: suffix ])
		ifTrue: [ ^ aName , 'es' ].
	((aName endsWith: 'y') and: [
		 aName size > 1 and: [ (aName at: aName size - 1) isVowel not ] ])
		ifTrue: [ ^ aName allButLast , 'ies' ].
	^ aName , 's'
]

{ #category : 'naming' }
MGModelSchemaBuilder >> preferredTypeNameOf: aConcept among: conceptsByShortName [
	| shortName |
	shortName := self graphQLNameFrom: aConcept shortName.
	^ ((conceptsByShortName at: aConcept shortName) size > 1 or: [
		   self isReservedTypeName: shortName ])
		  ifTrue: [ self graphQLNameFrom: aConcept fullName ]
		  ifFalse: [ shortName ]
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> primitivePropertiesOf: aConcept [
	"Primitive properties of the concept FM3 type, one per name, sorted by name.
	Also includes explicit temporal properties (see #isExplicitTemporalProperty:) and Object-typed properties holding scalar values in aConcept (see #isScalarObjectProperty:in:)"

	^ MGSafe
		  do: [
				  registry sortedUniqueByName:
					  aConcept fm3Type allPrimitiveProperties
					  , (aConcept fm3Type allComplexProperties select: [ :each |
								   (self isExplicitTemporalProperty: each) or: [
									   self isScalarObjectProperty: each in: aConcept ] ]) ]
		  default: #(  )
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> rawValueOf: anFM3Property in: anEntity [
	"Value of anFM3Property for anEntity, nil on error"

	^ MGSafe do: [ anEntity mmGetProperty: anFM3Property ] default: nil
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> registryFrom: aContext [
	"aContext when it is an MGRegistry, a fresh registry on the model otherwise"

	^ (aContext isKindOf: MGRegistry)
		  ifTrue: [ aContext ]
		  ifFalse: [ MGRegistry forModel: model ]
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> relationPropertiesOf: aConcept [
	"Entity-typed properties of the concept FM3 type, one per name, sorted by name.
	Object-typed properties holding scalar values in aConcept are excluded (see #isScalarObjectProperty:in:)"

	^ MGSafe
		  do: [
				  registry sortedUniqueByName:
					  (aConcept fm3Type allComplexProperties select: [ :each |
							   (self isRelationProperty: each) and: [
								   (self isScalarObjectProperty: each in: aConcept) not ] ]) ]
		  default: #(  )
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> rootConceptOfEntity: anEntity in: aContext [
	"The root concept whose FM3 type is the meta-class of anEntity, or nil"

	| meta |
	meta := (self registryFrom: aContext) metadescriptionOf: anEntity.
	meta ifNil: [ ^ nil ].
	^ (concepts at: meta ifAbsent: [ nil ]) ifNotNil: [ :concept |
		  concept isRoot
			  ifTrue: [ concept ]
			  ifFalse: [ nil ] ]
]

{ #category : 'accessing' }
MGModelSchemaBuilder >> rootConcepts [
	"The concepts having root fields on Query (concrete classes having instances), sorted by FM3 fullName"

	^ self concepts select: [ :each | each isRoot ]
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> runtimeTypeNameOf: anEntity in: aContext [
	"Name of the concept object type of anEntity (the root concept of its meta-class), nil when it has none. Type resolver of the MooseEntity interface"

	^ MGSafe
		  do: [
			  (self rootConceptOfEntity: anEntity in: aContext) ifNotNil: [ :concept |
				  concept typeName ] ]
		  default: nil
]

{ #category : 'object properties' }
MGModelSchemaBuilder >> sampledClassesOf: anFM3Property [
	"Concrete classes of the model conforming to the class declaring anFM3Property, all of them when there is none; sorted by fullName"

	| owner |
	owner := MGSafe do: [ anFM3Property mmClass ] default: nil.
	owner ifNil: [ ^ concreteClasses ].
	^ (self concreteClassesConformingTo: owner) ifEmpty: [ concreteClasses ]
]

{ #category : 'scalars' }
MGModelSchemaBuilder >> scalarNameFor: anFM3Property [
	"Scalar of anFM3Property from its type name: String, Boolean and Number map to themselves, Date to Date, Time to Time, DateAndTime, DateTime and Timestamp to DateTime, Duration to Duration, any other type (Object included) to String"

	| typeName |
	typeName := MGSafe
		            do: [ anFM3Property type name asString ]
		            default: ''.
	(#( 'String' 'Boolean' 'Number' ) includes: typeName) ifTrue: [
		^ typeName ].
	^ (self class temporalScalarNameForTypeNamed: typeName) ifNil: [
		  'String' ]
]

{ #category : 'scalars' }
MGModelSchemaBuilder >> scalarNameFor: anFM3Property in: aConcept [
	"Scalar of anFM3Property: inferred from the values for Object-typed properties (see #inferObjectScalarNameOf:), from the type name otherwise (see #scalarNameFor:)"

	(self isObjectProperty: anFM3Property) ifFalse: [
		^ self scalarNameFor: anFM3Property ].
	^ (self objectScalarNameOf: anFM3Property) ifNil: [ 'String' ]
]

{ #category : 'initialization' }
MGModelSchemaBuilder >> setModel: aMooseModel [

	model := aMooseModel.
	registry := MGRegistry forModel: aMooseModel.
	concreteClasses := #(  ).
	concepts := IdentityDictionary new.
	targets := IdentityDictionary new.
	supertypeSets := IdentityDictionary new.
	objectKinds := IdentityDictionary new
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> supertypeSetOf: anFM3Class [
	"anFM3Class and all its (non built-in) supertypes, superclasses and traits, cached per class"

	supertypeSets ifNil: [ supertypeSets := IdentityDictionary new ].
	^ supertypeSets at: anFM3Class ifAbsentPut: [
		  (registry withAllSupertypesOf: anFM3Class) asIdentitySet ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> targetConceptFor: aDeclaredType [
	"The concept typing a relation declared with aDeclaredType: the root concept of its single conforming concrete class, its helper concept otherwise (see #targetTypeFor:)"

	^ concepts at: (self targetTypeFor: aDeclaredType)
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> targetTypeFor: aDeclaredType [
	"The single concrete class of the model conforming to aDeclaredType when there is exactly one, aDeclaredType itself otherwise (see #isExposedRelation:)"

	| conforming |
	conforming := self concreteClassesConformingTo: aDeclaredType.
	^ conforming size = 1
		  ifTrue: [ conforming first ]
		  ifFalse: [ aDeclaredType ]
]

{ #category : 'naming' }
MGModelSchemaBuilder >> uniqueName: aName among: usedNames alternative: aSuffix [
	"aName when free in usedNames, otherwise aName , aSuffix, then aName , aSuffix , 2, 3...; the answer is added to usedNames"

	| candidate index |
	candidate := aName.
	(usedNames includes: candidate) ifTrue: [ candidate := aName , aSuffix ].
	index := 1.
	[ usedNames includes: candidate ] whileTrue: [
		index := index + 1.
		candidate := aName , aSuffix , index printString ].
	usedNames add: candidate.
	^ candidate
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> valueOf: anFM3Property in: anEntity converter: aBlock [
	"Single primitive value converted with aBlock, nil on error"

	^ MGSafe
		  do: [ (self rawValueOf: anFM3Property in: anEntity) ifNotNil: [ :value | aBlock value: value ] ]
		  default: nil
]

{ #category : 'resolving' }
MGModelSchemaBuilder >> valuesOf: anFM3Property in: anEntity converter: aBlock [
	"Multivalued primitive values (at most MGSchema maxTake) converted with aBlock, nil on error"

	^ MGSafe
		  do: [
			  (self rawValueOf: anFM3Property in: anEntity) ifNotNil: [ :value |
				  ((MGSafe isCollectionLike: value)
					   ifTrue: [ MGSafe take: MGSchema maxTake from: value ]
					   ifFalse: [ { value } ]) collect: [ :each |
					  each ifNotNil: [ aBlock value: each ] ] ] ]
		  default: nil
]
