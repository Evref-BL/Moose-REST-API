"
Please comment me using the following template inspired by Class Responsibility Collaborator (CRC) design:

For the Class part:  State a one line summary. For example, ""I represent a paragraph of text"".

For the Responsibility part: Three sentences about my main responsibilities - what I do, what I know.

For the Collaborators Part: State my main collaborators and one line about how I interact with them. 

Public API and Key Messages

- message one   
- message two 
- (for bonus points) how to create instances.

   One simple example is simply gorgeous.
 
Internal Representation and Key Implementation Points.


    Implementation Points
"
Class {
	#name : #BaselineOfMooseRestAPI,
	#superclass : #BaselineOf,
	#category : #BaselineOfMooseRestAPI
}

{ #category : #baselines }
BaselineOfMooseRestAPI >> baseline: spec [
	<baseline>
	spec
		for: #common
		do: [ 
			self defineDependencies: spec.
			self definePackages: spec.
			self defineGroups: spec ]
]

{ #category : #baselines }
BaselineOfMooseRestAPI >> defineDependencies: spec [

	spec
		baseline: 'Tealight'
		with: [ spec repository: 'github://astares/Tealight/repository' ].

	spec
		baseline: 'Roassal3Exporters'
		with: [ spec repository: 'github://ObjectProfile/Roassal3Exporters' ]
]

{ #category : #baselines }
BaselineOfMooseRestAPI >> defineGroups: spec [
	
]

{ #category : #baselines }
BaselineOfMooseRestAPI >> definePackages: spec [

	spec
		package: 'Moose-REST-API'
		with: [ spec requires: #( 'Tealight' 'Roassal3Exporters' ) ]
]
