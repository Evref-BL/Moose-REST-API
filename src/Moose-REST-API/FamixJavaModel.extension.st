Extension { #name : #FamixJavaModel }

{ #category : #'*Moose-REST-API' }
FamixJavaModel >> webRootEntities [
	^ self allModelNamespaces asOrderedCollection
]

{ #category : #'*Moose-REST-API' }
FamixJavaModel >> webSummary [

	| col |
	col := { 
		       { 
			       (#name -> #Classes).
			       (#value -> (self allWithSubTypesOf: FamixJavaClass) size) }
			       asDictionary.
		       { 
			       (#name -> #Method).
			       (#value -> (self allWithSubTypesOf: FamixJavaMethod) size) }
			       asDictionary.
		       { 
			       (#name -> #'Dead Entities').
			       (#value -> (self count: #isDead)) } asDictionary } asOrderedCollection.
	self replicationManager ifNotNil: [ 
		col add: { 
				(#name -> #'Code duplication').
				(#value
				 ->
					 (self replicationManager replicatedFragments sum: [ :duplication | 
						  duplication codeText lineCount * duplication replicas size ])) }
				asDictionary ].
	^ col
]
