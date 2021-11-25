Extension { #name : #FamixJavaModel }

{ #category : #'*Moose-REST-API' }
FamixJavaModel >> webSummary [

	^ { 
		  { 
			  (#name -> #Classes).
			  (#value -> (self allWithSubTypesOf: FamixJavaClass) size) }
			  asDictionary.
		  { 
			  (#name -> #Method).
			  (#value -> (self allWithSubTypesOf: FamixJavaMethod) size) }
			  asDictionary }
]
