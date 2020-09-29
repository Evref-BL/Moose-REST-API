Class {
	#name : #MROutput,
	#superclass : #TeaOutput,
	#category : #'Moose-REST-API'
}

{ #category : #'response transformers' }
MROutput class >> json [
	^ [ :aTeaResponse | | entity |
		entity := ZnStringEntity 
			with: ((self optionalClass: #MRJSONWriter) toString: aTeaResponse body) 
			type: (ZnMimeType applicationJson charSet: aTeaResponse charSet; yourself).
		self 
			znEntity: entity
			code: aTeaResponse code 
			headers: aTeaResponse headers ]
]
