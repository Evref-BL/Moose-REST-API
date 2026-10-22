"
Registry-level containment (container / children / ancestors / root entities) and supertype (classes + traits) protocol of MGRegistry, on the MGTestCase fixture (Class1 with a1, m1, m2; Class2 with m3).
"
Class {
	#name : 'MGContainmentTest',
	#superclass : 'MGTestCase',
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'tests' }
MGContainmentTest >> classDescription [
	"FM3 class of FamixTest1 Class in the fixture model metamodel"

	^ self registry fm3ClassNamed: 'Famix-Test1-Entities.Class' in: model
]

{ #category : 'tests' }
MGContainmentTest >> testAllSupertypesOfExcludesClass [
	"allSupertypesOf: is withAllSupertypesOf: without the class itself"

	| desc all |
	desc := self classDescription.
	all := self registry allSupertypesOf: desc.
	self deny: (all includes: desc).
	self assert: all asArray equals: (self registry withAllSupertypesOf: desc) allButFirst asArray
]

{ #category : 'tests' }
MGContainmentTest >> testAncestorsOfTake [
	"Containment chain, nearest container first, limited by take"

	self assert: (self registry ancestorsOf: m1 take: nil) asArray equals: { class1 }.
	self assert: (self registry ancestorsOf: a1 take: 1) asArray equals: { class1 }.
	self assert: (self registry ancestorsOf: m1 take: 0) isEmpty.
	self assert: (self registry ancestorsOf: class1 take: nil) isEmpty
]

{ #category : 'tests' }
MGContainmentTest >> testChildrenCountOf [
	"Number of distinct direct children"

	self assert: (self registry childrenCountOf: class1) equals: 3.
	self assert: (self registry childrenCountOf: class2) equals: 1.
	self assert: (self registry childrenCountOf: m1) equals: 0
]

{ #category : 'tests' }
MGContainmentTest >> testChildrenOfTake [
	"Children follow the sorted children properties (attributes, then methods); take limits the result; leaves have no children"

	self
		assert: ((self registry childrenOf: class1 take: nil) collect: [ :e | e name ]) asArray
		equals: #( 'a1' 'm1' 'm2' ).
	self
		assert: ((self registry childrenOf: class1 take: 2) collect: [ :e | e name ]) asArray
		equals: #( 'a1' 'm1' ).
	self assert: (self registry childrenOf: class1 take: 0) isEmpty.
	self assert: (self registry childrenOf: class2 take: nil) asArray equals: { m3 }.
	self assert: (self registry childrenOf: m1 take: nil) isEmpty
]

{ #category : 'tests' }
MGContainmentTest >> testContainerAndChildrenProperties [
	"Container / children FM3 properties of Class (traits included) are unique by name, sorted by name, cached; nil answers empty"

	| desc |
	desc := self classDescription.
	self assert: desc notNil.
	self
		assert: ((self registry containerPropertiesOf: desc) collect: [ :p | p name asString ]) asArray
		equals: #( 'parentPackage' 'typeContainer' ).
	self
		assert: ((self registry childrenPropertiesOf: desc) collect: [ :p | p name asString ]) asArray
		equals: #( 'attributes' 'comments' 'methods' ).
	self
		assert: (self registry childrenPropertiesOf: desc)
		identicalTo: (self registry childrenPropertiesOf: desc).
	self assert: (self registry containerPropertiesOf: nil) isEmpty.
	self assert: (self registry childrenPropertiesOf: nil) isEmpty
]

{ #category : 'tests' }
MGContainmentTest >> testContainerOfAndContainersOf [
	"Methods and attributes are contained by their class; classes have no container in the fixture; containersOf: never answers duplicates nor the entity itself"

	self assert: (self registry containerOf: m1) identicalTo: class1.
	self assert: (self registry containerOf: a1) identicalTo: class1.
	self assert: (self registry containerOf: m3) identicalTo: class2.
	self assert: (self registry containersOf: m1) asArray equals: { class1 }.
	self assert: (self registry containerOf: class1) isNil.
	self assert: (self registry containersOf: class1) isEmpty.
	{ class1. class2. m1. m2. m3. a1 } do: [ :e |
		| containers |
		containers := self registry containersOf: e.
		self deny: (containers includes: e).
		self assert: containers asIdentitySet size equals: containers size ]
]

{ #category : 'tests' }
MGContainmentTest >> testFm3ClassNamedFindsTraits [
	"fm3ClassNamed:in: also finds traits, by short or full name"

	| trait |
	trait := self registry fm3ClassNamed: 'TMethod' in: model.
	self assert: trait notNil.
	self assert: (trait isKindOf: FM3Trait).
	self assert: trait name asString equals: 'TMethod'.
	self
		assert: (self registry fm3ClassNamed: 'Famix-Traits.TMethod' in: model)
		identicalTo: trait.
	self assert: (self registry fm3ClassNamed: 'Nope' in: model) isNil
]

{ #category : 'tests' }
MGContainmentTest >> testRootEntities [
	"Root entities are the entities without container; unknown model ids answer an empty collection"

	self assert: (self registry isRootEntity: class1).
	self assert: (self registry isRootEntity: class2).
	self deny: (self registry isRootEntity: m1).
	self deny: (self registry isRootEntity: a1).
	self
		assert: (self registry rootEntitiesOf: model take: nil) asArray
		equals: { class1. class2 }.
	self assert: (self registry rootEntitiesOf: model take: 1) size equals: 1.
	self
		assert: (self registry rootEntitiesTake: nil modelId: self modelId) asArray
		equals: { class1. class2 }.
	self assert: (self registry rootEntitiesTake: nil modelId: '999999') isEmpty.
	self assert: (self registry rootEntitiesTake: nil modelId: 'nope') isEmpty.
	self assert: (self registry rootEntitiesTake: 1 modelId: nil) size <= 1.
	self assert: (self registry rootEntitiesTake: 0 modelId: nil) isEmpty
]

{ #category : 'tests' }
MGContainmentTest >> testSupertypeNamesOf [
	"Short names of the meta-class of an entity and of its supertypes, deduplicated"

	| names |
	names := self registry supertypeNamesOf: class1.
	self assert: names first equals: 'Class'.
	self assert: (names includes: 'TClass').
	self assert: (names includes: 'TNamedEntity').
	self assert: (names includes: 'NamedEntity').
	self assert: (names includes: 'Entity').
	self assert: names asSet size equals: names size
]

{ #category : 'tests' }
MGContainmentTest >> testWithAllSupertypesOf [
	"Class first, then TClass and the other traits, then superclasses; no duplicates, no built-in FM3 types"

	| desc all names |
	desc := self classDescription.
	all := self registry withAllSupertypesOf: desc.
	self assert: all first identicalTo: desc.
	self assert: all second name asString equals: 'TClass'.
	self assert: all asIdentitySet size equals: all size.
	names := all collect: [ :c | c fullName asString ].
	#( 'Famix-Traits.TNamedEntity' 'Famix-Traits.TWithComments' 'Famix-Traits.TWithMethods'
	   'Famix-Test1-Entities.NamedEntity' 'Famix-Test1-Entities.Entity' 'Moose.Entity' 'Moose.Object' )
		do: [ :n | self assert: (names includes: n) description: n , ' missing' ].
	#( 'Object' 'String' 'Boolean' 'Number' )
		do: [ :n | self deny: (names includes: n) description: n , ' is built-in' ].
	self assert: (self registry withAllSupertypesOf: nil) isEmpty
]
