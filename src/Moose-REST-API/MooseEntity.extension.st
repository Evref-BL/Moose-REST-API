Extension { #name : #MooseEntity }

{ #category : #'*Moose-REST-API' }
MooseEntity >> neoJsonOn: mrJSONWriter [
	"I can be used by subclass of MRJSONWriter"
	mrJSONWriter writeMooseEntity: self
]
