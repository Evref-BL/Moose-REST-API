"
I am the API to get the models
"
Class {
	#name : #MRAPIModels,
	#superclass : #MRAPI,
	#category : #'Moose-REST-API'
}

{ #category : #api }
MRAPIModels class >> models: aRequest [
	<REST_API: 'GET' versions: #('v1') pattern: 'models'>
	^ MROutput json
		value: (TeaResponse ok body: (MooseModel root collectWithIndex: [ :model :idx | {('id' -> idx) . ('name' -> model name)} asDictionary ]))
]
