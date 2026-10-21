"
Unit tests for MGRegistry: id round-trips for models, entities, meta-classes, relations and properties, robustness on bad ids, sorted properties/relations and the related-entities navigation. Also covers the MGProperty / MGRelation / MGMetaClass wrappers.
"
Class {
	#name : 'MGRegistryTest',
	#superclass : 'MGTestCase',
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'tests - ids' }
MGRegistryTest >> testBadIdsAnswerNil [
	"Malformed or unknown ids never raise: every lookup answers nil"

	| badIds |
	badIds := {
		          ''.
		          'zz'.
		          '999:1'.
		          'a/b/c'.
		          nil.
		          ':'.
		          '/'.
		          '1:'.
		          (self modelId , ':999999999').
		          '-5'.
		          '1:Nope'.
		          ((self idOf: class1) , '/nope').
		          ((self idOf: class1) , '/') }.
	badIds do: [ :id |
			self
				shouldnt: [
						self assert: (self registry entityAt: id) isNil.
						self assert: (self registry relationAt: id) isNil.
						self assert: (self registry propertyAt: id) isNil ]
				raise: Error ].
	{ ''. 'zz'. '999'. nil. '0' } do: [ :id |
			self
				shouldnt: [ self assert: (self registry modelAt: id) isNil ]
				raise: Error ].
	{
		''.
		'zz'.
		'999:Method'.
		nil.
		(self modelId , ':NoSuchClass').
		'a/b/c' } do: [ :id |
			self
				shouldnt: [ self assert: (self registry metaClassAt: id) isNil ]
				raise: Error ]
]

{ #category : 'tests - ids' }
MGRegistryTest >> testEntityRoundTrip [
	"Entity ids are '<modelId>:<mooseID>'; a bare mooseID is also accepted"

	{
		class1.
		class2.
		m1.
		m2.
		m3.
		a1 } do: [ :each |
			| id |
			id := self registry idOfEntity: each.
			self
				assert: id
				equals: self modelId , ':' , each mooseID printString.
			self assert: (self registry entityAt: id) identicalTo: each.
			self
				assert: (self registry entityAt: each mooseID printString)
				identicalTo: each.
			self
				assert: (self registry entityAt: ' ' , id , ' ')
				identicalTo: each ]
]

{ #category : 'tests - features' }
MGRegistryTest >> testEntityTypesAndEntitiesOfType [
	"entityTypesOf: lists the meta-classes with instances (sorted by name); entitiesOf:type: filters by meta-class name or fullName"

	| types methodType |
	types := self registry entityTypesOf: model.
	self
		assert: (types collect: [ :t | t name ]) asArray
		equals: #( 'Attribute' 'Class' 'Method' ).
	self
		assert: (types collect: [ :t | t count ]) asArray
		equals: #( 1 2 3 ).
	methodType := types last.
	self
		assert: (self registry entitiesOf: model type: 'Method') asSet
		equals: {
				m1.
				m2.
				m3 } asSet.
	self
		assert:
		(self registry entitiesOf: model type: methodType fullName) size
		equals: 3.
	self
		assert:
		(self registry entitiesOf: model type: 'FamixTest1Class') asSet
		equals: {
				class1.
				class2 } asSet.
	self
		assert: (self registry entitiesOf: model type: nil) size
		equals: 6.
	self assert:
		(self registry entitiesOf: model type: 'NoSuchType') isEmpty.
	self assert: (self registry entitiesOf: nil type: 'Method') isEmpty.
	self
		assert: (self registry entityTypesOf: model take: 1) size
		equals: 1
]

{ #category : 'tests - ids' }
MGRegistryTest >> testMetaClassRoundTrip [
	"Meta-class ids are '<modelId>:<FM3 fullName>'; the short name is also accepted"

	| metaClass found byShortName |
	metaClass := self registry metaClassOf: m1.
	self assert: metaClass notNil.
	self assert: metaClass name equals: 'Method'.
	self
		assert: metaClass id
		equals: self modelId , ':' , metaClass fullName.
	found := self registry metaClassAt: metaClass id.
	self assert: found equals: metaClass.
	self assert: found count equals: 3.
	byShortName := self registry metaClassAt: self modelId , ':Method'.
	self assert: byShortName equals: metaClass.
	self assert: byShortName instances asSet equals: {
			m1.
			m2.
			m3 } asSet.
	self assert: (byShortName instances: 2) size equals: 2
]

{ #category : 'tests - features' }
MGRegistryTest >> testMetaClassSuperclassAndEquality [
	"MGMetaClass wraps an FM3 class in the context of a model; equality is per (fm3Class, model)"

	| methodType again superclass |
	methodType := self registry metaClassOf: m1.
	again := self registry metaClassOf: m2.
	self assert: methodType equals: again.
	self assert: methodType hash equals: again hash.
	self deny: methodType equals: (self registry metaClassOf: class1).
	self assert: methodType model identicalTo: model.
	self assert: methodType modelId equals: self modelId.
	superclass := methodType superclass.
	self assert: superclass notNil.
	self assert: superclass modelId equals: self modelId.
	self assert: superclass name isString
]

{ #category : 'tests - ids' }
MGRegistryTest >> testModelRoundTrip [
	"A model is found back by its index id and by its name"

	| id |
	self assert: (self registry models includes: model).
	id := self registry idOfModel: model.
	self assert: id isString.
	self
		assert: id
		equals: (self registry models identityIndexOf: model) printString.
	self assert: (self registry modelAt: id) identicalTo: model.
	self
		assert: (self registry modelAt: 'MGTestModel')
		identicalTo: model.
	self assert: (self registry idOfModel: FamixTest1Model new) isNil
]

{ #category : 'tests - features' }
MGRegistryTest >> testPropertiesAndRelationsAreSorted [
	"Properties and relations are sorted by name and unique; name is a property, methods/attributes are relations"

	| propertyNames relationNames |
	propertyNames := (self registry propertiesOf: class1) collect: [ :p |
		                 p name ].
	relationNames := (self registry relationsOf: class1) collect: [ :r |
		                 r name ].
	self assert: propertyNames notEmpty.
	self assert: relationNames notEmpty.
	self
		assert: propertyNames asArray
		equals: propertyNames asSortedCollection asArray.
	self
		assert: relationNames asArray
		equals: relationNames asSortedCollection asArray.
	self assert: propertyNames asSet size equals: propertyNames size.
	self assert: relationNames asSet size equals: relationNames size.
	self assert: (propertyNames includes: 'name').
	self assert: (relationNames includes: 'methods').
	self assert: (relationNames includes: 'attributes').
	self deny: (propertyNames includes: 'methods').
	self deny: (relationNames includes: 'name')
]

{ #category : 'tests - ids' }
MGRegistryTest >> testPropertyRoundTrip [
	"Property ids are '<entityId>/<name>'"

	| property found |
	property := (self registry propertiesOf: class1) detect: [ :p |
		            p name = 'name' ].
	self assert: property id equals: (self idOf: class1) , '/name'.
	found := self registry propertyAt: property id.
	self assert: found notNil.
	self assert: found name equals: 'name'.
	self assert: found value equals: 'Class1'.
	self assert: found type equals: 'String'.
	self deny: found isDerived.
	self assert: found owner identicalTo: class1.
	"a relation name is not a property, and vice versa"
	self assert:
		(self registry propertyAt: (self idOf: class1) , '/methods') isNil.
	self assert:
		(self registry relationAt: (self idOf: class1) , '/name') isNil
]

{ #category : 'tests - features' }
MGRegistryTest >> testRelatedOf [
	"relatedOf:take: follows stored relations, including derived ones with an opposite such as Famix methods/attributes"

	| related |
	related := self registry relatedOf: class1 take: nil.
	self assert: (related includes: m1).
	self assert: (related includes: m2).
	self assert: (related includes: a1).
	self deny: (related includes: m3).
	self assert: related asIdentitySet size equals: related size.
	self assert: (self registry relatedOf: class1 take: 2) size equals: 2.
	self assert: (self registry relatedOf: class1 take: 0) isEmpty.
	"from the other side: a method reaches its parent type"
	self assert:
		((self registry relatedOf: m3 take: nil) includes: class2)
]

{ #category : 'tests - ids' }
MGRegistryTest >> testRelationRoundTrip [
	"Relation ids are '<entityId>/<name>'"

	| relation found |
	relation := (self registry relationsOf: class1) detect: [ :r |
		            r name = 'methods' ].
	self assert: relation id equals: (self idOf: class1) , '/methods'.
	found := self registry relationAt: relation id.
	self assert: found notNil.
	self assert: found name equals: 'methods'.
	self assert: found owner identicalTo: class1.
	self assert: found size equals: 2.
	self assert: found isMultivalued.
	self assert: found targets asSet equals: {
			m1.
			m2 } asSet.
	self assert: (found targets: 1) size equals: 1.
	self assert: (found target == m1 or: [ found target == m2 ]).
	"bare entity id works too"
	self assert:
		(self registry relationAt: class1 mooseID printString , '/methods')
			notNil
]

{ #category : 'tests - features' }
MGRegistryTest >> testUseModelsAndUnknownModel [
	"useModels: replaces the MooseModel root snapshot; entities of models outside the snapshot get a bare id"

	| other |
	other := MGRegistry new.
	other useModels: #(  ).
	self assert: other models isEmpty.
	self assert: (other modelAt: '1') isNil.
	self assert: (other entityAt: (self idOf: class1)) isNil.
	self
		assert: (other idOfEntity: class1)
		equals: class1 mooseID printString.
	self assert: (other knownModelOf: class1) isNil.
	self assert: (other metaClassOf: class1) isNil.
	other useModels: { model }.
	self assert: (other idOfModel: model) equals: '1'.
	self
		assert: (other entityAt: '1:' , class1 mooseID printString)
		identicalTo: class1
]
