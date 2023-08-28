*** Settings ***
Library          SeleniumLibrary
Library          lib/DataReader.py
Library          OperatingSystem
Library          String
Library          Collections

*** Variables ***
${URL1}            https://rpachallenge.com/
${URL2}            https://rpachallengeocr.azurewebsites.net/
${download_dir}    ${CURDIR}/downloads/
${output_dir}     ${CURDIR}/output/
${output_csv}     ${CURDIR}/output/invoice_data.csv
${output_txt}     ${CURDIR}/output/invoice_data.txt
${output_txt2}     ${CURDIR}/output/invoice_data2.txt

*** Test Cases ***
# Read Excel and Fill form using both
#     Read Excel and Fill form    Firefox
#     Read Excel and Fill form    headlessfirefox

Download Invoice Images
    Clean Downloads Directory
    Open Browser    ${URL2}    Firefox    service_log_path=${{os.path.devnull}}
    Maximize Browser Window
    TRY
        Click Element    //button[@id='start']
        FOR   ${i}    IN RANGE    1    4        

            ${id_list}=    Create List
            ${due_date_list}=    Create List
            FOR    ${row_index}    IN RANGE    1    5
                ${id} =    Get Text    //table[@id='tableSandbox']//tbody/tr[${row_index}]/td[2]
                Append To List    ${id_list}    ${id}  # Hozzáadás a listához
                ${due_date} =    Get Text    //table[@id='tableSandbox']//tbody/tr[${row_index}]/td[3]
                Append To List    ${due_date_list}    ${due_date}  # Hozzáadás a listához
            END

            @{invoice_links}=    Get WebElements    xpath=//a[contains(@href, '/invoices/') and not(contains(@href, 'example.csv')) and not(contains(@href, 'sample'))]
            ${index}=   Set Variable    0
            FOR    ${link}    IN    @{invoice_links}

                ${download_path}=    Set Variable    ${download_dir}
                ${href}=    Get Element Attribute    ${link}    href
                                   
                Execute Javascript    window.open("${href}", "_blank")
                # Váltás az újonnan megnyitott ablakra
                Switch Window    NEW
                # Várj a letöltésre, majd zárd be az ablakot
                Wait Until Page Contains Element    //img[contains(@src, 'https://rpachallengeocr.azurewebsites.net/invoices/')]
                ${img_element}=    Get WebElement    xpath=//img[contains(@src, 'https://rpachallengeocr.azurewebsites.net/invoices/')]
                ${img_src}=    Get Element Attribute    ${img_element}    src
                ${filename}=    Evaluate    "${img_src}".split("/")[-1]
                ${download_path}=    Set Variable    ${download_dir}//${filename}

                ${download_successful}=    download_file    ${img_src}    ${download_path}
                Should Be True    ${download_successful}
                File Should Exist    ${download_path}
                Close Window
                # Visszaváltás az eredeti ablakra
                Switch Window    MAIN
                
                ${id}=    Get From List    ${id_list}    ${index}
                ${due_date}=    Get From List    ${due_date_list}    ${index}
                Extract And Save CSV    ${id}    ${due_date}    ${download_path}                    
                ${index}=    Evaluate    ${index} + 1
            END
        Click Element    //a[@id='tableSandbox_next']
        END
        rewrite_first_line    ${output_txt2}    ${output_csv}
        Click Element    //div[@id='submit']
            
    EXCEPT
        Close All Browsers
        Fail
        
    END

*** Keywords ***
Clean Downloads Directory
    Remove Directory    ${download_dir}    True
    Create Directory    ${download_dir}
    Remove Directory    ${output_dir}    True
    Create Directory    ${output_dir}

Extract And Save CSV
    [Arguments]    ${id}    ${due_date}    ${download_path}    
    ${output} =    Run And Return Rc And Output    pytesseract ${download_path}
    ${text} =    Get From List    ${output}    1
    Log Many    \n${text}
    append_to_txt   ${output_txt}    ${text}
    ${info}=    extract_invoice_info    ${text}    ${id}    ${due_date}
    append_to_txt   ${output_txt2}    ${info}
    Log Many    \n${info}
    
    #Append To CSV    ${output_csv}    ${info}

Read Excel and Fill form
    [Arguments]    ${browser}
    ${data}     read_excel    ${CURDIR}/input/challenge.xlsx
    Log Many          @{data}
    Open Browser    ${URL1}    ${browser}    service_log_path=${{os.path.devnull}}
    Maximize Browser Window
    Page Should Not Contain    //label[text()='First Name']/following-sibling::input
    TRY
        Click Button    //button[text()='Start']
        FOR    ${row}    IN    @{data}

            ${js_code}=    Catenate
                ...    document.querySelector('[ng-reflect-name="labelFirstName"]').value = "${row['First Name']}";
                ...    document.querySelector('[ng-reflect-name="labelLastName"]').value = "${row['Last Name ']}";
                ...    document.querySelector('[ng-reflect-name="labelEmail"]').value = "${row['Email']}";
                ...    document.querySelector('[ng-reflect-name="labelCompanyName"]').value = "${row['Company Name']}";
                ...    document.querySelector('[ng-reflect-name="labelPhone"]').value = "${row['Phone Number']}";
                ...    document.querySelector('[ng-reflect-name="labelAddress"]').value = "${row['Address']}";
                ...    document.querySelector('[ng-reflect-name="labelRole"]').value = "${row['Role in Company']}";
            Execute JavaScript    ${js_code}
            Execute JavaScript    document.querySelector('input[type="submit"]').click()    # Kattintás a Submit gombra            
        END

        ${text}=    Get Text    //div[@class='message2']
        Log to Console    \n${text}
        Close Browser
        
    EXCEPT
        Fail
        Close Browser
    END
