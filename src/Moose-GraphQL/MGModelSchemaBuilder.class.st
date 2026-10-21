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
		'builder'
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

{ #category : 'instance creation' }
MGModelSchemaBuilder class >> on: aMooseModel [

	^ self new setModel: aMooseModel
]

{ #category : 'naming' }
MGModelSchemaBuilder class >> reservedTypeNames [
	"Names that a concept type may not take (besides names starting with __)"

	^ #( 'Query' 'String' 'Int' 'Float' 'Boolean' 'ID' 'Number' )
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

{ #category : 'concepts' }
MGModelSchemaBuilder >> addHelperConceptFor: anFM3Type [
	"Register the hidden helper concept of anFM3Type, the declared type of a relation satisfied by several concrete classes of the model"

	^ concepts at: anFM3Type put: (MGConcept
			   helperType: anFM3Type
			   conformingClasses: (self concreteClassesConformingTo: anFM3Type))
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> addRootConceptFor: anFM3Class [
	"Register the root concept of anFM3Class, a concrete class having instances in the model"

	^ concepts at: anFM3Class put: (MGConcept
			   rootType: anFM3Class
			   conformingClasses:
			   (self concreteClassesConformingTo: anFM3Class))
]

{ #category : 'naming' }
MGModelSchemaBuilder >> assignRootFieldNames [
	"Singular lowerFirst by-id fields first (e.g. method), then plural lowerFirst list fields (e.g. methods), all unique; root concepts only"

	| used roots |
	used := Set new.
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
		assignRootFieldNames.
	builder := GQLSchemaBuilder new.
	self
		defineNumberScalar;
		defineQuery;
		defineConceptTypes.
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

{ #category : 'accessing' }
MGModelSchemaBuilder >> conceptFor: anFM3Type [
	"The concept standing for anFM3Type (concrete class or declared relation type)"

	^ concepts at: (self targetTypeFor: anFM3Type)
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
		^ [ :value | (value == true or: [ value == false ]) ifTrue: [ value ] ] ].
	aScalarName = 'Number' ifTrue: [
		^ [ :value | value isNumber ifTrue: [ value ] ] ].
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
			fields: [ :object | self defineFieldsOf: each on: object ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineFieldsOf: aConcept on: anObjectTypeBuilder [

	| used |
	used := Set withAll: #( 'id' 'name' 'type' ).
	self defineIdentityFieldsOn: anObjectTypeBuilder.
	(self primitivePropertiesOf: aConcept) do: [ :property |
			(self fieldNameFor: property among: used) ifNotNil: [ :name |
				self
					definePrimitiveField: name
					for: property
					on: anObjectTypeBuilder ] ].
	(self exposedRelationPropertiesOf: aConcept) do: [ :property |
			(self fieldNameFor: property among: used) ifNotNil: [ :name |
				self
					defineRelationField: name
					for: property
					on: anObjectTypeBuilder ] ]
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
MGModelSchemaBuilder >> definePrimitiveField: aName for: anFM3Property on: anObjectTypeBuilder [
	| scalar converter |
	scalar := self scalarNameFor: anFM3Property.
	converter := self converterFor: scalar.
	(self isMultivalued: anFM3Property)
		ifTrue: [
			anObjectTypeBuilder
				field: aName
				type: '[' , scalar , ']'
				description: (self descriptionOf: anFM3Property)
				resolve: [ :entity :args :context |
					self valuesOf: anFM3Property in: entity converter: converter ] ]
		ifFalse: [
			anObjectTypeBuilder
				field: aName
				type: scalar
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
				self rootConcepts do: [ :each |
					self defineRootFieldsOf: each on: object ] ]
]

{ #category : 'building' }
MGModelSchemaBuilder >> defineRelationField: aName for: anFM3Property on: anObjectTypeBuilder [
	| target |
	target := (self conceptFor: anFM3Property type) typeName.
	(self isMultivalued: anFM3Property)
		ifTrue: [
			anObjectTypeBuilder
				field: aName
				type: '[' , target , '!]!'
				description: (self descriptionOf: anFM3Property)
				args: { ('take' -> 'Int') }
				resolve: [ :entity :args :context |
					MGSafe
						take: (MGSchema arg: 'take' in: args)
						from: (self entitiesOf: anFM3Property in: entity) ] ]
		ifFalse: [
			anObjectTypeBuilder
				field: aName
				type: target
				description: (self descriptionOf: anFM3Property)
				resolve: [ :entity :args :context |
					(self entitiesOf: anFM3Property in: entity)
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

{ #category : 'concepts' }
MGModelSchemaBuilder >> exposedRelationPropertiesOf: aConcept [
	"Relation properties of aConcept that may hold entities of the model, sorted by name"

	^ (self relationPropertiesOf: aConcept) select: [ :each |
		  self isExposedRelation: each ]
]

{ #category : 'naming' }
MGModelSchemaBuilder >> fieldNameFor: anFM3Property among: usedNames [
	"GraphQL field name of anFM3Property (id is renamed id_), or nil when already used"

	| name |
	name := self graphQLNameFrom: (MGSafe do: [ anFM3Property name asString ] default: '').
	name = 'id' ifTrue: [ name := 'id_' ].
	(usedNames includes: name) ifTrue: [ ^ nil ].
	usedNames add: name.
	^ name
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

{ #category : 'concepts' }
MGModelSchemaBuilder >> isClass: anFM3Class conformingTo: anFM3Type [
	"True when anFM3Class is anFM3Type, inherits from it, or (directly or by inheritance) uses it as a trait.
	FM3Class>>#classUsers answers the class itself, FM3Trait>>#classUsers the classes using the trait."

	^ MGSafe
		  do: [
			  anFM3Type classUsers anySatisfy: [ :user |
				  user == anFM3Class or: [ anFM3Class inheritsFrom: user ] ] ]
		  default: false
]

{ #category : 'concepts' }
MGModelSchemaBuilder >> isConceptClass: anFM3Class [
	^ MGSafe
		  do: [ anFM3Class isBuiltIn not and: [ anFM3Class isPrimitive not ] ]
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

{ #category : 'concepts' }
MGModelSchemaBuilder >> isRelationProperty: anFM3Property [
	^ MGSafe
		  do: [ anFM3Property type notNil and: [ anFM3Property type isPrimitive not ] ]
		  default: false
]

{ #category : 'naming' }
MGModelSchemaBuilder >> isReservedTypeName: aString [
	^ (self class reservedTypeNames includes: aString) or: [
		  aString beginsWith: '__' ]
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
	"Primitive properties of the concept FM3 type, one per name, sorted by name"

	^ MGSafe
		  do: [ registry sortedUniqueByName: aConcept fm3Type allPrimitiveProperties ]
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
	"Entity-typed properties of the concept FM3 type, one per name, sorted by name"

	^ MGSafe
		  do: [
			  registry sortedUniqueByName:
				  (aConcept fm3Type allComplexProperties select: [ :each |
					   self isRelationProperty: each ]) ]
		  default: #(  )
]

{ #category : 'accessing' }
MGModelSchemaBuilder >> rootConcepts [
	"The concepts having root fields on Query (concrete classes having instances), sorted by FM3 fullName"

	^ self concepts select: [ :each | each isRoot ]
]

{ #category : 'scalars' }
MGModelSchemaBuilder >> scalarNameFor: anFM3Property [
	"String, Boolean and Number map to themselves, any other primitive type to String"

	| typeName |
	typeName := MGSafe do: [ anFM3Property type name asString ] default: ''.
	^ (#( 'String' 'Boolean' 'Number' ) includes: typeName)
		  ifTrue: [ typeName ]
		  ifFalse: [ 'String' ]
]

{ #category : 'initialization' }
MGModelSchemaBuilder >> setModel: aMooseModel [
	model := aMooseModel.
	registry := MGRegistry forModel: aMooseModel.
	concreteClasses := #(  ).
	concepts := IdentityDictionary new.
	targets := IdentityDictionary new
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
