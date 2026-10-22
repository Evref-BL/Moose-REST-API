"
I am the per-request user context of the Moose GraphQL layer. I snapshot the installed Moose models, translate opaque ids from/to objects and cache expensive lookups for the duration of one request.

Ids:
- Model: index in the models snapshot (lookup also accepts the model name)
- Entity: '<modelId>:<mooseID>' (lookup also accepts a bare mooseID)
- MetaClass: '<modelId>:<FM3 fullName>'
- Property / Relation: '<entityId>/<propertyName>'

Unknown or malformed ids answer nil; I never raise.
"
Class {
	#name : 'MGRegistry',
	#superclass : 'Object',
	#instVars : [
		'models',
		'entityIndexes',
		'instancesCache',
		'entityTypesCache',
		'containerPropertiesCache',
		'childrenPropertiesCache',
		'supertypesCache'
	],
	#category : 'Moose-GraphQL-Core',
	#package : 'Moose-GraphQL',
	#tag : 'Core'
}

{ #category : 'instance creation' }
MGRegistry class >> forModel: aMooseModel [
	"A registry whose model snapshot is only aMooseModel (used by the model-specific schema)"

	^ self new useModels: { aMooseModel }
]

{ #category : 'private' }
MGRegistry >> addSupertype: anFM3Type to: aCollection seen: aSet [
	"Add anFM3Type (unless built-in) then, depth-first, its direct traits sorted by fullName"
	| traits |
	(anFM3Type isNil or: [ aSet includes: anFM3Type ]) ifTrue: [ ^ self ].
	aSet add: anFM3Type.
	(self isBuiltInType: anFM3Type) ifFalse: [ aCollection add: anFM3Type ].
	traits := MGSafe do: [ anFM3Type traits asArray ] default: #().
	((traits ifNil: [ #() ]) asSortedCollection: [ :a :b | (self fullNameOf: a) <= (self fullNameOf: b) ])
		do: [ :each | self addSupertype: each to: aCollection seen: aSet ]
]

{ #category : 'entities' }
MGRegistry >> allEntitiesType: aStringOrNil [
	"Entities of all models matching aStringOrNil"
	^ self allEntitiesType: aStringOrNil limit: SmallInteger maxVal
]

{ #category : 'private' }
MGRegistry >> allEntitiesType: aStringOrNil limit: anInteger [
	| result |
	anInteger <= 0 ifTrue: [ ^ #() ].
	result := OrderedCollection new.
	self models do: [ :model |
		result addAll: (self entitiesOf: model type: aStringOrNil limit: anInteger - result size).
		result size >= anInteger ifTrue: [ ^ result asArray ] ].
	^ result asArray
]

{ #category : 'entities' }
MGRegistry >> allEntitiesType: aStringOrNil take: aTakeOrNil [
	"At most aTakeOrNil (normalized) entities matching aStringOrNil, scanning the models lazily"
	^ self allEntitiesType: aStringOrNil limit: (MGSafe normalizeTake: aTakeOrNil)
]

{ #category : 'supertypes' }
MGRegistry >> allSupertypesOf: anFM3Class [
	"Same as #withAllSupertypesOf: without anFM3Class itself"
	^ (self withAllSupertypesOf: anFM3Class) reject: [ :each | each == anFM3Class ]
]

{ #category : 'containment' }
MGRegistry >> ancestorsOf: anEntity take: aTakeOrNil [
	"Containment chain of anEntity (following #containerOf:), nearest container first, at most aTakeOrNil; stops on cycles"
	| limit seen result current |
	limit := MGSafe normalizeTake: aTakeOrNil.
	limit = 0 ifTrue: [ ^ #() ].
	seen := IdentitySet with: anEntity.
	result := OrderedCollection new.
	current := self containerOf: anEntity.
	[ current notNil and: [ result size < limit and: [ (seen includes: current) not ] ] ] whileTrue: [
		seen add: current.
		result add: current.
		current := self containerOf: current ].
	^ result asArray
]

{ #category : 'containment' }
MGRegistry >> childrenCountOf: anEntity [
	"Number of distinct entities directly contained by anEntity"
	| seen |
	seen := IdentitySet new.
	[ (self childrenPropertiesOf: (self metadescriptionOf: anEntity)) do: [ :p |
		self
			entitiesIn: (MGSafe do: [ anEntity mmGetProperty: p ] default: nil)
			do: [ :each | each == anEntity ifFalse: [ seen add: each ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ seen size
]

{ #category : 'containment' }
MGRegistry >> childrenOf: anEntity take: aTakeOrNil [
	"Distinct entities directly contained by anEntity (values of its children properties), at most aTakeOrNil; iteration stops early"
	| limit seen result |
	limit := MGSafe normalizeTake: aTakeOrNil.
	limit = 0 ifTrue: [ ^ #() ].
	seen := IdentitySet with: anEntity.
	result := OrderedCollection new.
	[ (self childrenPropertiesOf: (self metadescriptionOf: anEntity)) do: [ :p |
		self
			entitiesIn: (MGSafe do: [ anEntity mmGetProperty: p ] default: nil)
			do: [ :each |
				(seen includes: each) ifFalse: [
					seen add: each.
					result add: each.
					result size >= limit ifTrue: [ ^ result asArray ] ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result asArray
]

{ #category : 'containment' }
MGRegistry >> childrenPropertiesOf: anFM3Class [
	"FM3 properties of anFM3Class (traits included) whose values are contained by the owner (opposite of a container property), one per name, sorted by name"
	anFM3Class ifNil: [ ^ #() ].
	childrenPropertiesCache ifNil: [ childrenPropertiesCache := IdentityDictionary new ].
	^ childrenPropertiesCache at: anFM3Class ifAbsentPut: [
		MGSafe
			do: [ self sortedUniqueByName: (anFM3Class allProperties select: [ :p | MGSafe do: [ p isChildrenProperty == true ] default: false ]) ]
			default: #() ]
]

{ #category : 'properties' }
MGRegistry >> complexPropertiesOf: anEntity [
	"Entity-typed properties of anEntity, one per name, sorted by name; Object-typed properties holding a non-entity value are excluded (see #isScalarObjectProperty:of:)"

	^ MGSafe
		  do: [
				  self sortedUniqueByName:
					  ((self metadescriptionOf: anEntity) allComplexProperties
						   select: [ :p |
								   (MGSafe
									    do: [ p type notNil and: [ p type isPrimitive not ] ]
									    default: false) and: [
									   (self isScalarObjectProperty: p of: anEntity) not ] ]) ]
		  default: #(  )
]

{ #category : 'containment' }
MGRegistry >> containerOf: anEntity [
	"First direct container of anEntity, or nil"
	^ (self containersOf: anEntity) ifEmpty: [ nil ] ifNotEmpty: [ :containers | containers first ]
]

{ #category : 'containment' }
MGRegistry >> containerPropertiesOf: anFM3Class [
	"FM3 properties of anFM3Class (traits included) whose value contains the owner, one per name, sorted by name"
	anFM3Class ifNil: [ ^ #() ].
	containerPropertiesCache ifNil: [ containerPropertiesCache := IdentityDictionary new ].
	^ containerPropertiesCache at: anFM3Class ifAbsentPut: [
		MGSafe
			do: [ self sortedUniqueByName: (anFM3Class allProperties select: [ :p | MGSafe do: [ p isContainer == true ] default: false ]) ]
			default: #() ]
]

{ #category : 'containment' }
MGRegistry >> containersOf: anEntity [
	"Distinct entities directly containing anEntity (values of its container properties), never anEntity itself"
	| seen result |
	seen := IdentitySet with: anEntity.
	result := OrderedCollection new.
	[ (self containerPropertiesOf: (self metadescriptionOf: anEntity)) do: [ :p |
		self
			entitiesIn: (MGSafe do: [ anEntity mmGetProperty: p ] default: nil)
			do: [ :each |
				(seen includes: each) ifFalse: [
					seen add: each.
					result add: each ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result asArray
]

{ #category : 'private' }
MGRegistry >> entitiesIn: anObject do: aBlock [
	"Evaluate aBlock on each Moose entity found in anObject (single entity, collection or group); may raise"
	anObject ifNil: [ ^ self ].
	(MGSafe isEntity: anObject) ifTrue: [ ^ aBlock value: anObject ].
	(MGSafe isCollectionLike: anObject) ifFalse: [ ^ self ].
	anObject do: [ :each | (MGSafe isEntity: each) ifTrue: [ aBlock value: each ] ]
]

{ #category : 'entities' }
MGRegistry >> entitiesOf: aMooseModel type: aStringOrNil [
	"All entities of aMooseModel matching aStringOrNil (see #entity:matchesType:)"
	^ self entitiesOf: aMooseModel type: aStringOrNil limit: SmallInteger maxVal
]

{ #category : 'private' }
MGRegistry >> entitiesOf: aMooseModel type: aStringOrNil limit: anInteger [
	"At most anInteger entities of aMooseModel matching aStringOrNil; iteration stops early"
	| result |
	(aMooseModel isNil or: [ anInteger <= 0 ]) ifTrue: [ ^ #() ].
	result := OrderedCollection new.
	[ (self entitiesOfModel: aMooseModel) do: [ :each |
		(self entity: each matchesType: aStringOrNil) ifTrue: [
			result add: each.
			result size >= anInteger ifTrue: [ ^ result asArray ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result asArray
]

{ #category : 'entities' }
MGRegistry >> entitiesOf: aMooseModel type: aStringOrNil take: aTakeOrNil [
	"At most aTakeOrNil (normalized) entities of aMooseModel matching aStringOrNil"
	^ self entitiesOf: aMooseModel type: aStringOrNil limit: (MGSafe normalizeTake: aTakeOrNil)
]

{ #category : 'models' }
MGRegistry >> entitiesOfModel: aMooseModel [
	"All entities of aMooseModel; empty on error"
	^ MGSafe do: [ aMooseModel entities ifNil: [ #() ] ] default: [ #() ]
]

{ #category : 'entities' }
MGRegistry >> entitiesTake: aTakeOrNil modelId: aModelIdOrNil type: aStringOrNil [
	"Query.entities: restricted to one model when aModelIdOrNil is given (unknown model -> empty)"
	aModelIdOrNil ifNil: [ ^ self allEntitiesType: aStringOrNil take: aTakeOrNil ].
	^ (self modelAt: aModelIdOrNil)
		ifNil: [ #() ]
		ifNotNil: [ :model | self entitiesOf: model type: aStringOrNil take: aTakeOrNil ]
]

{ #category : 'entities' }
MGRegistry >> entity: anEntity matchesType: aStringOrNil [
	"True if aStringOrNil is nil/empty or names the meta-class (name or fullName) or the Smalltalk class of anEntity"
	(aStringOrNil isNil or: [ aStringOrNil isEmpty ]) ifTrue: [ ^ true ].
	^ MGSafe
		do: [ | d |
			d := self metadescriptionOf: anEntity.
			(d notNil and: [ (self safeNameOf: d) = aStringOrNil or: [ (MGSafe do: [ d fullName asString ] default: nil) = aStringOrNil ] ])
				or: [ anEntity class name asString = aStringOrNil ] ]
		default: false
]

{ #category : 'entities' }
MGRegistry >> entityAt: anId [
	"Entity for '<modelId>:<mooseID>' or a bare mooseID; nil if unknown"
	^ MGSafe
		do: [ | key colon mooseId |
			anId ifNil: [ ^ nil ].
			key := anId asString trimBoth.
			colon := key lastIndexOf: $:.
			mooseId := self parseInteger: (key allButFirst: colon).
			mooseId ifNil: [ ^ nil ].
			colon = 0
				ifTrue: [
					self models do: [ :m | (self entityIndexOf: m) at: mooseId ifPresent: [ :e | ^ e ] ].
					nil ]
				ifFalse: [
					(self modelAt: (key first: colon - 1))
						ifNil: [ nil ]
						ifNotNil: [ :m | (self entityIndexOf: m) at: mooseId ifAbsent: [ nil ] ] ] ]
		default: nil
]

{ #category : 'accessing - concepts' }
MGRegistry >> entityAt: anId ofAnyOf: someFM3Classes [
	"Entity for anId (see #entityAt:) when its metadescription is one of someFM3Classes, nil otherwise"

	^ (self entityAt: anId) ifNotNil: [ :entity |
			  (MGSafe
				   do: [
				   someFM3Classes includes: (self metadescriptionOf: entity) ]
				   default: false) ifTrue: [ entity ] ]
]

{ #category : 'entities' }
MGRegistry >> entityIndexOf: aMooseModel [
	"Lazily built Dictionary mooseID -> entity for aMooseModel"
	aMooseModel ifNil: [ ^ Dictionary new ].
	^ entityIndexes at: aMooseModel ifAbsentPut: [
		| index |
		index := Dictionary new.
		[ (self entitiesOfModel: aMooseModel) do: [ :each |
			(self mooseIdOf: each) ifNotNil: [ :id | index at: id put: each ] ] ]
			on: Error
			do: [ :e | e return: nil ].
		index ]
]

{ #category : 'meta classes' }
MGRegistry >> entityTypesOf: aMooseModel [
	"Meta-classes having at least one instance in aMooseModel, sorted by name"
	aMooseModel ifNil: [ ^ #() ].
	^ entityTypesCache at: aMooseModel ifAbsentPut: [
		MGSafe
			do: [ (((self instancesIndexOf: aMooseModel) keys
				asSortedCollection: [ :a :b | (self safeNameOf: a) <= (self safeNameOf: b) ])
				collect: [ :each | self metaClassFor: each model: aMooseModel ]) asArray
				reject: [ :each | each isNil ] ]
			default: #() ]
]

{ #category : 'meta classes' }
MGRegistry >> entityTypesOf: aMooseModel take: aTakeOrNil [
	^ MGSafe take: aTakeOrNil from: (self entityTypesOf: aMooseModel)
]

{ #category : 'meta classes' }
MGRegistry >> fm3ClassNamed: aString in: aMooseModel [
	"FM3Class or FM3Trait of the model metamodel whose fullName (or name) is aString, or nil"
	| classes |
	classes := MGSafe do: [ aMooseModel metamodel classes asOrderedCollection ] default: [ OrderedCollection new ].
	classes addAll: (MGSafe do: [ aMooseModel metamodel traits asArray ] default: [ #() ]).
	classes addAll: (MGSafe do: [ (self instancesIndexOf: aMooseModel) keys ] default: [ #() ]).
	^ (classes detect: [ :c | (MGSafe do: [ c fullName asString ] default: nil) = aString ] ifNone: [ nil ])
		ifNil: [ classes detect: [ :c | (MGSafe do: [ c name asString ] default: nil) = aString ] ifNone: [ nil ] ]
]

{ #category : 'private' }
MGRegistry >> fullNameOf: anFM3Element [
	^ MGSafe do: [ anFM3Element fullName asString ] default: [ String new ]
]

{ #category : 'entities' }
MGRegistry >> idOfEntity: anEntity [
	"<modelId>:<mooseID>, or the bare mooseID when the entity is not in a known model"
	^ MGSafe
		do: [ | mooseId modelId |
			mooseId := (self mooseIdOf: anEntity) ifNil: [ ^ nil ].
			modelId := self idOfModel: (self modelOf: anEntity).
			modelId
				ifNil: [ mooseId printString ]
				ifNotNil: [ modelId , ':' , mooseId printString ] ]
		default: nil
]

{ #category : 'models' }
MGRegistry >> idOfModel: aMooseModel [
	"Index of aMooseModel in the snapshot as a String, or nil"
	| index |
	aMooseModel ifNil: [ ^ nil ].
	index := self models identityIndexOf: aMooseModel.
	^ index = 0 ifTrue: [ nil ] ifFalse: [ index printString ]
]

{ #category : 'initialization' }
MGRegistry >> initialize [
	super initialize.
	entityIndexes := IdentityDictionary new.
	instancesCache := IdentityDictionary new.
	entityTypesCache := IdentityDictionary new
]

{ #category : 'meta classes' }
MGRegistry >> instancesIndexOf: aMooseModel [
	"Lazily built IdentityDictionary FM3Class -> OrderedCollection of entities of aMooseModel (one scan)"
	aMooseModel ifNil: [ ^ IdentityDictionary new ].
	^ instancesCache at: aMooseModel ifAbsentPut: [
		| index |
		index := IdentityDictionary new.
		[ (self entitiesOfModel: aMooseModel) do: [ :each |
			(self metadescriptionOf: each) ifNotNil: [ :d |
				(index at: d ifAbsentPut: [ OrderedCollection new ]) add: each ] ] ]
			on: Error
			do: [ :e | e return: nil ].
		index ]
]

{ #category : 'meta classes' }
MGRegistry >> instancesOf: anFM3Class model: aMooseModel [
	"Entities of aMooseModel whose metadescription is anFM3Class"
	^ MGSafe
		do: [ (self instancesIndexOf: aMooseModel) at: anFM3Class ifAbsent: [ OrderedCollection new ] ]
		default: [ OrderedCollection new ]
]

{ #category : 'accessing - concepts' }
MGRegistry >> instancesOfAll: someFM3Classes model: aMooseModel take: aTakeOrNil [
	"At most aTakeOrNil (normalized) entities of aMooseModel whose metadescription is one of someFM3Classes, in the order of someFM3Classes"

	| limit result |
	limit := MGSafe normalizeTake: aTakeOrNil.
	limit = 0 ifTrue: [ ^ #(  ) ].
	result := OrderedCollection new.
	[
		someFM3Classes do: [ :each |
				(self instancesOf: each model: aMooseModel) do: [ :entity |
						result add: entity.
						result size >= limit ifTrue: [ ^ result asArray ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result asArray
]

{ #category : 'private' }
MGRegistry >> isBuiltInType: anFM3Type [
	"True for FM3 built-in types (Object, primitives) that are not part of the metamodel"
	^ MGSafe
		do: [ anFM3Type isBuiltIn == true or: [ (anFM3Type respondsTo: #isPrimitive) and: [ anFM3Type isPrimitive == true ] ] ]
		default: false
]

{ #category : 'properties' }
MGRegistry >> isNavigable: anMGRelation [
	"A relation is navigable for #relatedOf:take: when it is stored: either not derived, or one side of an opposite pair.
	In Famix the 'many' side of an opposite pair (e.g. Class>>methods) is flagged derived although it is a real stored slot;
	purely computed derived relations (no opposite) are skipped because they can be expensive."

	^ MGSafe
		  do: [
				  anMGRelation isDerived not or: [
					  anMGRelation property opposite notNil ] ]
		  default: false
]

{ #category : 'containment' }
MGRegistry >> isRootEntity: anEntity [
	"True when anEntity has no container"
	^ (self containersOf: anEntity) isEmpty
]

{ #category : 'private' }
MGRegistry >> isScalarObjectProperty: anFM3Property of: anEntity [
	"True when anFM3Property is typed Object (FM3Object) and its value for anEntity is set but holds no entity (e.g. a DateAndTime): it is then a property, not a relation"

	^ MGSafe
		  do: [
				  (anFM3Property type isKindOf: FM3Object) and: [
						  (anEntity mmGetProperty: anFM3Property) in: [ :value |
							  value notNil and: [ (MGSafe entitiesIn: value) isEmpty ] ] ] ]
		  default: false
]

{ #category : 'entities' }
MGRegistry >> knownModelOf: anEntity [
	"The model of anEntity when it belongs to the installed models snapshot, nil otherwise"

	^ (self modelOf: anEntity) ifNotNil: [ :m |
		  (self idOfModel: m) ifNotNil: [ m ] ]
]

{ #category : 'meta classes' }
MGRegistry >> metaClassAt: anId [
	"Meta-class for '<modelId>:<FM3 fullName or name>'; nil if unknown"
	^ MGSafe
		do: [ | key colon model className fm3 |
			anId ifNil: [ ^ nil ].
			key := anId asString trimBoth.
			colon := key indexOf: $:.
			colon = 0 ifTrue: [ ^ nil ].
			model := (self modelAt: (key first: colon - 1)) ifNil: [ ^ nil ].
			className := key allButFirst: colon.
			fm3 := self fm3ClassNamed: className in: model.
			self metaClassFor: fm3 model: model ]
		default: nil
]

{ #category : 'meta classes' }
MGRegistry >> metaClassFor: anFM3Class model: aMooseModel [
	"Wrap anFM3Class in the context of aMooseModel; nil if the model is unknown"
	| modelId |
	anFM3Class ifNil: [ ^ nil ].
	modelId := (self idOfModel: aMooseModel) ifNil: [ ^ nil ].
	^ MGMetaClass model: aMooseModel modelId: modelId fm3Class: anFM3Class registry: self
]

{ #category : 'entities' }
MGRegistry >> metaClassOf: anEntity [
	^ MGSafe
		do: [ (self metadescriptionOf: anEntity) ifNotNil: [ :d | self metaClassFor: d model: (self modelOf: anEntity) ] ]
		default: nil
]

{ #category : 'entities' }
MGRegistry >> metadescriptionOf: anEntity [
	^ MGSafe do: [ anEntity metadescription ] default: nil
]

{ #category : 'models' }
MGRegistry >> metamodelNameOf: aMooseModel [
	"Name of the class of the model, which identifies its metamodel (e.g. FamixJavaModel)"
	^ MGSafe do: [ aMooseModel class name asString ] default: nil
]

{ #category : 'models' }
MGRegistry >> modelAt: anId [
	"Model for an index id or a model name; nil if unknown"
	^ MGSafe
		do: [ | key index |
			anId ifNil: [ ^ nil ].
			key := anId asString trimBoth.
			index := (key notEmpty and: [ key allSatisfy: [ :c | c isDigit ] ])
				ifTrue: [ key asInteger ]
				ifFalse: [ 0 ].
			(index between: 1 and: self models size)
				ifTrue: [ self models at: index ]
				ifFalse: [ self models detect: [ :m | (MGSafe do: [ m name asString ] default: nil) = key ] ifNone: [ nil ] ] ]
		default: nil
]

{ #category : 'models' }
MGRegistry >> modelNameOf: aMooseModel [
	^ MGSafe do: [ aMooseModel name ifNotNil: [ :n | n asString ] ] default: nil
]

{ #category : 'entities' }
MGRegistry >> modelOf: anEntity [
	^ MGSafe do: [ anEntity mooseModel ] default: nil
]

{ #category : 'models' }
MGRegistry >> modelSizeOf: aMooseModel [
	^ MGSafe do: [ aMooseModel size ] default: [ MGSafe do: [ aMooseModel entities size ] default: nil ]
]

{ #category : 'models' }
MGRegistry >> models [
	"Snapshot of the installed Moose models, taken once per registry"
	^ models ifNil: [
		models := MGSafe do: [ MooseModel root asOrderedCollection ] default: [ OrderedCollection new ] ]
]

{ #category : 'models' }
MGRegistry >> modelsTake: aTakeOrNil [
	^ MGSafe take: aTakeOrNil from: self models
]

{ #category : 'entities' }
MGRegistry >> mooseIdOf: anEntity [
	^ MGSafe do: [ anEntity mooseID ] default: nil
]

{ #category : 'entities' }
MGRegistry >> mooseNameOf: anEntity [
	^ MGSafe do: [ anEntity mooseName ifNotNil: [ :n | n asString ] ] default: nil
]

{ #category : 'entities' }
MGRegistry >> nameOfEntity: anEntity [
	"The entity name when it has one, its mooseName otherwise"
	^ MGSafe
		do: [ | n |
			n := (anEntity respondsTo: #name) ifTrue: [ anEntity name ] ifFalse: [ nil ].
			n ifNil: [ self mooseNameOf: anEntity ] ifNotNil: [ n asString ] ]
		default: [ self mooseNameOf: anEntity ]
]

{ #category : 'private' }
MGRegistry >> parseInteger: aString [
	"Answer the Integer denoted by aString (digits only, optional leading minus) or nil"
	| s |
	s := aString trimBoth.
	s ifEmpty: [ ^ nil ].
	(s first = $- ) ifTrue: [ ^ (self parseInteger: s allButFirst) ifNotNil: [ :n | n negated ] ].
	(s allSatisfy: [ :c | c isDigit ]) ifFalse: [ ^ nil ].
	^ s asInteger
]

{ #category : 'properties' }
MGRegistry >> primitivePropertiesOf: anEntity [
	"Primitive properties of anEntity, plus its Object-typed properties holding a non-entity value (see #isScalarObjectProperty:of:), one per name, sorted by name"

	^ MGSafe
		  do: [
				  | description |
				  description := self metadescriptionOf: anEntity.
				  self sortedUniqueByName: description allPrimitiveProperties
					  , (description allComplexProperties select: [ :p |
							   self isScalarObjectProperty: p of: anEntity ]) ]
		  default: #(  )
]

{ #category : 'properties' }
MGRegistry >> propertiesOf: anEntity [
	"Primitive properties of anEntity sorted by name, wrapped in MGProperty"
	^ MGSafe
		do: [ (self primitivePropertiesOf: anEntity) collect: [ :p | MGProperty entity: anEntity property: p registry: self ] ]
		default: #()
]

{ #category : 'properties' }
MGRegistry >> propertyAt: anId [
	"MGProperty for '<entityId>/<propertyName>', or nil"
	^ MGSafe
		do: [ (self splitFeatureId: anId) ifNotNil: [ :pair |
				(self propertiesOf: pair first) detect: [ :p | p name = pair second ] ifNone: [ nil ] ] ]
		default: nil
]

{ #category : 'properties' }
MGRegistry >> relatedOf: anEntity take: aTakeOrNil [
	"Union of the targets of the navigable relations of anEntity (see #isNavigable:), without duplicates, at most aTakeOrNil"

	| limit seen result |
	limit := MGSafe normalizeTake: aTakeOrNil.
	seen := IdentitySet new.
	result := OrderedCollection new.
	limit = 0 ifTrue: [ ^ #(  ) ].
	[
		(self relationsOf: anEntity) do: [ :relation |
				(self isNavigable: relation) ifTrue: [
						relation values do: [ :each |
								(seen includes: each) ifFalse: [
										seen add: each.
										result add: each.
										result size >= limit ifTrue: [ ^ result asArray ] ] ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result asArray
]

{ #category : 'properties' }
MGRegistry >> relationAt: anId [
	"MGRelation for '<entityId>/<propertyName>', or nil"
	^ MGSafe
		do: [ (self splitFeatureId: anId) ifNotNil: [ :pair |
				(self relationsOf: pair first) detect: [ :r | r name = pair second ] ifNone: [ nil ] ] ]
		default: nil
]

{ #category : 'properties' }
MGRegistry >> relationsOf: anEntity [
	"Entity-typed properties of anEntity sorted by name, wrapped in MGRelation"
	^ MGSafe
		do: [ (self complexPropertiesOf: anEntity) collect: [ :p | MGRelation entity: anEntity property: p registry: self ] ]
		default: #()
]

{ #category : 'private' }
MGRegistry >> rootEntitiesOf: aMooseModel limit: anInteger [
	"At most anInteger entities of aMooseModel without container; iteration stops early"
	| result |
	(aMooseModel isNil or: [ anInteger <= 0 ]) ifTrue: [ ^ #() ].
	result := OrderedCollection new.
	[ (self entitiesOfModel: aMooseModel) do: [ :each |
		((MGSafe isEntity: each) and: [ self isRootEntity: each ]) ifTrue: [
			result add: each.
			result size >= anInteger ifTrue: [ ^ result asArray ] ] ] ]
		on: Error
		do: [ :e | e return: nil ].
	^ result asArray
]

{ #category : 'containment' }
MGRegistry >> rootEntitiesOf: aMooseModel take: aTakeOrNil [
	"At most aTakeOrNil (normalized) entities of aMooseModel without container"
	^ self rootEntitiesOf: aMooseModel limit: (MGSafe normalizeTake: aTakeOrNil)
]

{ #category : 'containment' }
MGRegistry >> rootEntitiesTake: aTakeOrNil modelId: aModelIdOrNil [
	"Query.rootEntities: entities without container, restricted to one model when aModelIdOrNil is given (unknown model -> empty)"
	| limit result |
	limit := MGSafe normalizeTake: aTakeOrNil.
	aModelIdOrNil ifNotNil: [
		^ (self modelAt: aModelIdOrNil)
			ifNil: [ #() ]
			ifNotNil: [ :model | self rootEntitiesOf: model limit: limit ] ].
	limit <= 0 ifTrue: [ ^ #() ].
	result := OrderedCollection new.
	self models do: [ :model |
		result addAll: (self rootEntitiesOf: model limit: limit - result size).
		result size >= limit ifTrue: [ ^ result asArray ] ].
	^ result asArray
]

{ #category : 'private' }
MGRegistry >> safeNameOf: anFM3Element [
	^ MGSafe do: [ anFM3Element name asString ] default: ''
]

{ #category : 'private' }
MGRegistry >> sortedUniqueByName: aCollection [
	"Answer the FM3 properties of aCollection, one per name, sorted by name"
	| byName |
	byName := Dictionary new.
	aCollection do: [ :each |
		(self safeNameOf: each) ifNotEmpty: [ :n | byName at: n ifAbsentPut: [ each ] ] ].
	^ (byName keys asSortedCollection: [ :a :b | a <= b ]) asArray collect: [ :n | byName at: n ]
]

{ #category : 'private' }
MGRegistry >> splitFeatureId: anId [
	"Answer an Array {entity. propertyName} for '<entityId>/<propertyName>', or nil"
	| key slash entity |
	anId ifNil: [ ^ nil ].
	key := anId asString trimBoth.
	slash := key lastIndexOf: $/.
	slash <= 1 ifTrue: [ ^ nil ].
	entity := (self entityAt: (key first: slash - 1)) ifNil: [ ^ nil ].
	^ { entity. key allButFirst: slash }
]

{ #category : 'supertypes' }
MGRegistry >> supertypeNamesOf: anEntity [
	"Short names of the meta-class of anEntity and all its supertypes, without duplicates"
	| names |
	names := OrderedCollection new.
	(self withAllSupertypesOf: (self metadescriptionOf: anEntity)) do: [ :each |
		| n |
		n := self safeNameOf: each.
		(n isEmpty or: [ names includes: n ]) ifFalse: [ names add: n ] ].
	^ names asArray
]

{ #category : 'entities' }
MGRegistry >> typeOfEntity: anEntity [
	"Name of the entity meta-class, or of its Smalltalk class"
	^ MGSafe
		do: [ (self metadescriptionOf: anEntity)
			ifNil: [ anEntity class name asString ]
			ifNotNil: [ :d | d name asString ] ]
		default: [ MGSafe do: [ anEntity class name asString ] default: nil ]
]

{ #category : 'models' }
MGRegistry >> useModels: aCollection [
	"Use aCollection instead of the MooseModel root snapshot (mostly for tests)"
	models := aCollection asOrderedCollection
]

{ #category : 'supertypes' }
MGRegistry >> withAllSupertypesOf: anFM3Class [
	"anFM3Class, then each of its superclasses, each followed by its traits (depth-first, sorted by fullName); no duplicates, no built-in types"
	anFM3Class ifNil: [ ^ #() ].
	supertypesCache ifNil: [ supertypesCache := IdentityDictionary new ].
	^ supertypesCache at: anFM3Class ifAbsentPut: [
		| result seen current |
		result := OrderedCollection new.
		seen := IdentitySet new.
		current := anFM3Class.
		[ current notNil and: [ (seen includes: current) not ] ] whileTrue: [
			self addSupertype: current to: result seen: seen.
			current := MGSafe do: [ current superclass ] default: nil ].
		result asArray ]
]
