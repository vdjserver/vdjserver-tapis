import airr
import json

def create_vdjpipe_job_files(data, project_id, project_name='', early_stop=None, save=True):
    '''
    Parameters
    ----------
    data : dict
        - From `airr.read_airr('/path/to/repertoires.airr.json')`
    project_id : str
        - The project's UUID
    project_name : str
        - The name of the project to add to output files.
    save : boolean
        -  If `True`, JSON will be dumped and make one job file per library.

    Returns
    -------
    json_contents : list
        - Returns a list where each element is JSON job file contents for a library from `data`
    '''

    json_contents = []

    # for lib in libraries:
    seq_for_files_source_urls = []
    seq_for_files = []
    seq_rev_files_source_urls = []
    seq_rev_files = []
    for rep in data['Repertoire']:
        for samp in rep['sample']:
            seq_for_files_source_urls.append('tapis://data-storage.vdjserver.org/projects/'+project_id+'/files/'+samp['sequencing_files']['filename'])
            seq_for_files.append(samp['sequencing_files']['filename'])
            seq_rev_files_source_urls.append('tapis://data-storage.vdjserver.org/projects/'+project_id+'/files/'+samp['sequencing_files']['paired_filename'])
            seq_rev_files.append(samp['sequencing_files']['paired_filename'])

            if early_stop is not None:
                if len(seq_for_files) == early_stop:
                    break
        if early_stop is not None:
                if len(seq_for_files) == early_stop:
                    break
    seq_for_files = ' '.join(seq_for_files)
    seq_rev_files = ' '.join(seq_rev_files) 

    content = {
        'name' : project_name,
        'appId' : 'vdjpipe-ls6',
        'appVersion' : '0.5',
        'maxMinutes' : 8*60,
        'nodeCount' : 1,
        'archiveSystemId' : 'data-storage.vdjserver.org',
        'archiveSystemDir' : '/projects/'+project_id+'/analyses/${JobUUID}',
        'fileInputArrays' : [{'name' : 'SequenceForwardPairedFiles', 'sourceUrls' : seq_for_files_source_urls},
                            {'name' : 'SequenceReversePairedFiles', 'sourceUrls' : seq_rev_files_source_urls}],
        'fileInputs' : [{'name' : 'ForwardPrimerFile', 'sourceUrl' : 'tapis://data-storage.vdjserver.org/projects/'+project_id+'/files/primers.fasta', 'targetPath' : 'primers.fasta'}],
        'parameterSet' : {
            'schedulerOptions' : [
                {'name' : 'allocation', 'arg' : '-A MCB23006'}
            ],
            'containerArgs' : [
            ],
            'appArgs' : [
            ],
            'envVariables' : [
                {'key' : 'Workflow', 'value' : 'paired'},
                {'key' : 'SequenceForwardPairedFiles', 'value' : seq_for_files},
                {'key' : 'SequenceForwardPairedFilesMetadata', 'value' : '12348'},
                {'key' : 'SequenceReversePairedFiles', 'value' : seq_rev_files},
                {'key' : 'SequenceReversePairedFilesMetadata', 'value' : '4567'},
                {'key' : 'MergeMinimumScore', 'value' : '10'},
                {'key' : 'PreFilterStatisticsFlag', 'value' : '1'},
                {'key' : 'FilterFlag', 'value' : '1'},
                {'key' : 'PostFilterStatisticsFlag', 'value' : '1'},
                {'key' : 'MinimumAverageQuality', 'value' : '35'},
                {'key' : 'MinimumLength', 'value' : '250'},
                {'key' : 'MaximumHomopolymer', 'value' : '20'},
                {'key' : 'ForwardPrimer', 'value' : '1'},
                {'key' : 'ForwardPrimerMaximumMismatches', 'value' : '0'},
                {'key' : 'ForwardPrimerTrim', 'value' : '1'},
                {'key' : 'ForwardPrimerSearchWindow', 'value' : '50'},
                {'key' : 'FindUniqueFlag', 'value' : '1'}
            ]
        }
    }
    json_contents.append(content)

    
    file_name = 'job-vdjpipe-'+project_name+'.json'
    
    if save:
        with open(file_name, 'w') as json_file:
            json.dump(json_contents[-1], json_file, indent=4)
    
    return json_contents

def create_igblast_job_file(data, project_id, project_name='', early_stop=None, nodes=1, save=True):
    '''
    Parameters
    ----------
    data : dict
        - From `airr.read_airr('/path/to/repertoires.airr.json')`
    project_id : str
        - The project's UUID
    project_name : str
        - The name of the project to add to output files.
    save : boolean
        -  If `True`, JSON will be dumped and make one job file.

    Returns
    -------
    json_contents
        - Returns a JSON job file with contents for a library from `data`
    '''
    # Create file lists
    seq_for_files_source_urls = []
    seq_for_files = []
    rep_ids = []

    if type(project_id) == tuple:
        orig_project_id = project_id[0]
        test_project_id = project_id[1]
    else:
        orig_project_id = project_id
        test_project_id = project_id

    for rep in data['Repertoire']:
        for samp, data in zip(rep['sample'], rep['data_processing']):
            if data['software_versions'].split('-')[0] != 'igblast':
                continue

            fasta_file_name = samp['sequencing_files']['filename']
            seq_for_files_source_urls.append('tapis://data-storage.vdjserver.org/projects/'+orig_project_id+'/files/'+fasta_file_name)
            seq_for_files.append(fasta_file_name)
            rep_ids.append(rep['repertoire_id'])

            if early_stop is not None:
                if len(seq_for_files) == early_stop:
                    break
        if early_stop is not None:
                if len(seq_for_files) == early_stop:
                    break
            
    seq_for_files = ' '.join(seq_for_files)
    rep_ids = ' '.join(rep_ids)

    file_name = 'job-igblast-'+project_name+'.json' if project_name else 'job-igblast.json'

    if project_name == '':
        project_name = test_project_id
    
    # Fill in contents
    json_contents = {
        'name' : project_name,
        'appId' : 'igblast-ls6',
        'appVersion' : '0.5',
        'maxMinutes' : min(len(seq_for_files_source_urls)*60*6, 2*24*60),
        'nodeCount' : nodes,
        'archiveSystemId' : 'data-storage.vdjserver.org',
        'archiveSystemDir' : '/projects/'+test_project_id+'/analyses/${JobUUID}',
        'fileInputs' : [{'name' : 'AIRRMetadata', 'sourceUrl' : 'tapis://data-storage.vdjserver.org/projects/'+test_project_id+'/files/repertoires.airr.json', 'targetPath' : 'repertoires.airr.json'}],
        'fileInputArrays' : [{'name' : 'query', 'sourceUrls' : seq_for_files_source_urls}],
        'parameterSet' : {
            'schedulerOptions' : [
                {'name' : 'allocation', 'arg' : '-A MCB23006'}
            ],
            'containerArgs' : [
            ],
            'appArgs' : [
            ],
            'envVariables' : [
                {'key' : 'query', 'value' : seq_for_files },
                {'key' : 'repertoires', 'value' :  rep_ids},
                {'key' : 'species', 'value' : 'human' },
                {'key' : 'locus', 'value' : 'IG' },
                {'key' : 'ClonalTool', 'value' : 'changeo' }
            ]
        }
    }
    
    if save:
        with open(file_name, 'w') as json_file:
            json.dump(json_contents, json_file, indent=4)
    
    return json_contents

def create_repcalc_job_file(data, project_id, project_name='', early_stop=None, save=True):
    '''
    Parameters
    ----------
    data : dict
        - From `airr.read_airr('/path/to/repertoires.airr.json')`
    project_id : str
        - The project's UUID
    job_id : str or list
        - The job's UUID as a string or a list
    project_name : str
        - The project's name (optional)
    save : boolean
        -  If `True`, JSON will be dumped and make one job file. (optional, default=True)

    Returns
    -------
    json_contents
        - Returns a JSON job file with contents for a library from `data`
    '''
    # Create file
    if type(job_id) != list:
        if type(job_id) == str:
            job_id = [job_id]
        elif type(job_id) == tuple:
            job_id = list(job_id)
        else:
            print('job_id not an acceptable format. Must be of string, list, or tuple, not '+str(type(job_id)))
    
    zip_files_source_urls = []
    zip_files = ' '.join([job+'.zip' for job in job_id])
    rep_ids = []

    for rep in data['Repertoire']:
        for samp in rep['sample']:
            airrtsv_file_name = '.'.join((samp['sequencing_files']['filename'].split('.')[0:-1] + ['airr', 'tsv']))
            zip_files_source_urls.append('tapis://data-storage.vdjserver.org/projects/'+project_id+'/files/'+airrtsv_file_name)
            zip_files.append(airrtsv_file_name)
            rep_ids.append(rep['repertoire_id'])

            if early_stop is not None:
                if len(zip_files) == early_stop:
                    break
        if early_stop is not None:
                if len(zip_files) == early_stop:
                    break


    file_name = 'job-repcalc-'+project_name+'.json' if project_name else 'job-repcalc.json'

    if project_name == '':
        project_name = project_id
    
    # Fill in contents
    json_contents = {
        'name' : project_name,
        'appId' : 'repcalc2-ls6',
        'appVersion' : '0.5',
        'maxMinutes' : 24*60,
        'nodeCount' : 1,
        'archiveSystemId' : 'data-storage.vdjserver.org',
        'archiveSystemDir' : '/projects/'+project_id+'/analyses/${JobUUID}',
        'fileInputs' : [{'name' : 'AIRRMetadata', 'sourceUrl' : 'tapis://data-storage.vdjserver.org/projects/'+project_id+'/files/repertoires.airr.json', 'targetPath' : 'repertoires.airr.json'}],
        'fileInputArrays' : [{'name' : 'JobFiles', 'sourceUrls' : zip_files_source_urls}],
        'parameterSet' : {
            'schedulerOptions' : [
                {'name' : 'allocation', 'arg' : '-A MCB23006'}
            ],
            'containerArgs' : [
            ],
            'appArgs' : [
            ],
            'envVariables' : [
                {'key' : 'JobFiles', 'value' : zip_files },
                {'key' : 'species', 'value' : 'human' },
                {'key' : 'locus', 'value' : 'IG' },
                {'key' : 'GeneSegmentFlag', 'value' : '1' },
                {'key' : 'CDR3Flag', 'value' : '1' },
                {'key' : 'DiversityFlag', 'value' : '1' },
                {'key' : 'ClonalFlag', 'value' : '1' },
                {'key' : 'MutationalFlag', 'value' : '1' }
            ]
        }
    }
    
    if save:
        with open(file_name, 'w') as json_file:
            json.dump(json_contents, json_file, indent=4)
    
    return json_contents


def main():
    # VDJ Pipe
    orig_project_id='7544045180439490070-242ac116-0001-012'
    test_project_id='1cc6b81a-c70f-4eeb-ac40-7de18f44ecdd'

    data = airr.read_airr('./repertoires.airr.json')

    for stop_num in [1, 2, 4, 8, 16, 32]:
        for node_num in [1,2,4,8]:
            create_igblast_job_file(data, (orig_project_id, test_project_id), 'Crowe-fasta-test-'+str(stop_num)+'files-'+str(node_num)+'nodes', stop_num, node_num)

if __name__ == '__main__':
    main()