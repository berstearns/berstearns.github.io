title: projects
slug: projects 
navbar_position: 2

# Pr&ecirc;t-&agrave;-LLOD Projects

Our projects are all available at [GitHub](https://github.com/pret-a-LLOD/)

## [termitup](https://github.com/pret-a-LLOD/termitup)

TermitUp is a tool for terminology enrichment: given a domain specific corpus, TermitUp performs statistical terminology extraction (with TBXTools) and cleans the resulting term list with a series of liguistic processes. Then, it queries several language resources (some part of the Linguistic Linked Open Data cloud) for candidate terms matching those in the term list.
TermitUp builds sense indicators for both the source and the candidate terms, and performs a Word Sense Disambiguation process (with Semantic Web Company's service), matching those concepts with the closest domain. From the concepts matched in the external resources, TermitUp retrieves every piece of information available (translations, synonyms, definitions and terminological relations), already disambiguated, and enriches the source term lists, creating links amongst the resources in the LLOD.
Afterwards, TermitUp offers the possibility of creating hierarchical relations amongst the terms in the source list and also of validating the synonymy relations retrieved from the external resources. Finally, the results are published in separate json-ld files, modeled in SKOS-XL, that permits keeping the provenance of specific pieces of the data retrieved.

## [teanga](https://github.com/pret-a-LLOD/teanga)

Teanga is a command-line tool that automates and facilitates using sequences of containerized rest api as a workflow. It aims at creation of complex Natural Language Processing workflows using Airflow, OpenAPI specification and docker.

## [term-a-LLOD](https://github.com/pret-a-LLOD/term-a-LLOD)

A system for transforming and publishing terminologies as linked data which relies on a virtualization approach (i.e. docker). The system simplifies the transformation and hosting of terminological resources. As a proof-of-concept we publish and link the well-known IATE terminology as well as to various smaller terminologies. The program is written in java.


## [pddm](https://github.com/pret-a-LLOD/pddm)

Policy Driven Data Manager

## [CIDER-EM](https://github.com/pret-a-LLOD/CIDER-EM)

Context and Inference baseD ontology alignER.
CIDER-EM is a word-embedding-based system for monolingual and cross-lingual ontology alignment. Evolves the CIDER-CL tool by including the use of word embeddings.

## [linghub](https://github.com/pret-a-LLOD/linghub)

linghub

## [ontology-lexicalization](https://github.com/pret-a-LLOD/ontology-lexicalization)

The system extracts property lexicalization patterns from a set of annotated (i.e. DBpedia/Wikidata annotated) Corpora and to To extract RDF graph patterns corresponding to an ngram and develops a Lemon Lexicon. The program is developed using perl and java.

## [Fintan](https://github.com/pret-a-LLOD/Fintan)

Flexible INtegrated Transformation and Annotation eNgineering platform

## [PaL-Linking](https://github.com/pret-a-LLOD/PaL-Linking)

Collection of components (submodules) that constitute the Prêt-à-LLOD linking framework
