# helper commands for tapis v3 apps

APP_NAME=repcalc2
APP_VERSION=0.3
APP_SYSTEM=ls6

APP_ID=${APP_NAME}-${APP_SYSTEM}
APP_FULL=${APP_ID}-${APP_VERSION}
APP_JSON=${APP_ID}.json
APP_ARCHIVE=${APP_FULL}.tgz
BUILD_DIR=build-${APP_FULL}

SCRIPTS_DIR=../../../scripts

# note: "help" MUST be the first target in the file,
# when the user types "make" they should get help info
help:
	@echo ""
	@echo "Helper commands for app: ${APP_FULL}"
	@echo "Assumes you are running in docker with tapis functions."
	@echo ""
	@echo "JSON app description:"
	@echo "make list      -- List tapis apps"
	@echo "make create    -- Create tapis app, only once"
	@echo "make update    -- Update tapis app description"
	@echo ""
	@echo "App assets:"
	@echo "make clean     -- Clean build files"
	@echo "make build     -- Build archive from app assets"
	@echo "make deploy    -- Deploy app assets"
	@echo ""
	@echo "Testing:"
	@echo "make test-tcr  -- Submit test TCR job"
	@echo "make test-bcr  -- Submit test BCR job"
	@echo "make test-all  -- Submit all test jobs"
	@echo ""

list:
	vdjserver-tools apps list

create:
	vdjserver-tools apps create ${APP_JSON}

update:
	vdjserver-tools apps update ${APP_ID} ${APP_VERSION} ${APP_JSON}

clean:
	rm -rf ${BUILD_DIR} ${APP_ARCHIVE}

common-scripts:
	mkdir ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/common_functions.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/provenance_functions.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/airr_metadata.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/process_metadata.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/repcalc_create_config.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/parse_changeo.py ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/gene_usage_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/gene_combo_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/junction_length_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/junction_distribution_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/junction_shared_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/junction_compare_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/aa_properties.R ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/clonal_abundance.R ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/diversity_curve.R ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/create_germlines.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/mutational_analysis.sh ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/mutational_analysis.R ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/mutational_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/mutational_analysis_template.json ${BUILD_DIR}
	cp ${SCRIPTS_DIR}/mutational_clones_template.json ${BUILD_DIR}

build: clean common-scripts
	cp ${APP_JSON} ${BUILD_DIR}
	cp tapisjob_app.sh ${BUILD_DIR}
	cp repcalc_common.sh ${BUILD_DIR}
	cp get_parameter.py ${BUILD_DIR}
	tar zcf ${APP_ARCHIVE} -C ${BUILD_DIR} .

deploy: build
	vdjserver-tools files upload ${APP_ARCHIVE} /apps/${APP_ARCHIVE}

test-bcr:
	vdjserver-tools jobs submit test/test-bcr.json

test-tcr:
	vdjserver-tools jobs submit test/test-tcr.json

test-all:
	vdjserver-tools jobs submit test/test-bcr.json
	vdjserver-tools jobs submit test/test-tcr.json
	vdjserver-tools jobs submit test/test-bcr4.json
	vdjserver-tools jobs submit test/test-cdr3-bcr4.json
	vdjserver-tools jobs submit test/test-gene-bcr4.json
	vdjserver-tools jobs submit test/test-mutations-bcr4.json
