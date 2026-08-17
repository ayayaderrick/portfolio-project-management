CLASS ltcl_ppm_project DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA: environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS: class_setup.
    CLASS-METHODS: class_teardown.

    METHODS setup.
    METHODS terdown.

ENDCLASS.


CLASS ltcl_ppm_project IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_osql_test_environment=>create(
        i_dependency_list = VALUE #(
            ( 'ZPPM_PROJECT_A' )
            ( 'ZPPM_PROJECT_D' )
            ( 'ZPPM_MILESTONE_A' )
            ( 'ZPPM_MILESTOME_D' )
            ( 'ZPPM_TASK_A' )
            ( 'ZPPM_TASK_D' )
         )
     ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy(  ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles(  ).
  ENDMETHOD.

  METHOD terdown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

ENDCLASS.
