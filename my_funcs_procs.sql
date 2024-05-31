
/*################################################################################*/
/*                                      FONCTION                                  */
/*################################################################################*/


/* Fonction GET NB WORKERS */

CREATE OR REPLACE FUNCTION GET_NB_WORKERS(
    FACTOR NUMBER                                                   /* paramètre de la fonction, qui doit être un entier */
)
RETURN NUMBER                                                       /* retourne un entier */ 
IS
    NUM_WORKERS NUMBER;                                             /* variable de stockage pour le nombre de travailleurs */
BEGIN
    SELECT COUNT(*) INTO NUM_WORKERS                                /* comptabilisation des travailleurs par usine et stockage dans num_worker */          
    FROM (                                                          
        SELECT 1                                                    /* début de la sous requette pour parser les deux tables worker factory */ 
        FROM WORKERS_FACTORY_1                                      /* ajoute un (au dessus) lorsque le travailleurs est toujours présent dans worker factory 1 */        
        WHERE last_day IS NULL AND FACTOR = 1                       /* et que l'usine renseignée en paramètre est bien 1 */
        AND EXISTS (                                                
            SELECT 1                                                /* vérifie que l'usine existe bien */
            FROM FACTORIES
            WHERE id = 1
        )
        UNION ALL                                                   /* union pour faire les mêmes opérations sur worker facto 2 */
        SELECT 1 
        FROM WORKERS_FACTORY_2 
        WHERE end_date IS NULL AND FACTOR = 2
        AND EXISTS (
            SELECT 1
            FROM FACTORIES
            WHERE id = 2
        )
    ); 
    RETURN NUM_WORKERS;                                             /* renvoie le résultats de la variable (variables déclarée 8eme ligne) */
EXCEPTION
    WHEN NO_DATA_FOUND THEN                                         /* condition de sortie si rien n'est trouvé, renvoie 0 */
        RETURN 0;
END GET_NB_WORKERS;                                                 /* fin de la fonction */
/                                                                   /*  à la fin si jamais le code est executé en sqlplus */

/* Test de la fonction */ 

SELECT GET_NB_WORKERS(1) AS nb_workers_in_factory_1 FROM DUAL;


/* Fonction GET_NB_BIG_ROBOTS */

CREATE OR REPLACE FUNCTION GET_NB_BIG_ROBOTS RETURN NUMBER IS 
    NUM_BIG_ROBOTS NUMBER; 
BEGIN 
    SELECT COUNT(*)                                         /*Compter le nombre de robots ayant plus de 3 pièces détachées */
    INTO NUM_BIG_ROBOTS 
    FROM ( 
        SELECT robot_id 
        FROM ROBOTS_HAS_SPARE_PARTS 
        GROUP BY robot_id 
        HAVING COUNT(spare_part_id) > 3 
    ); 
 
    RETURN NUM_BIG_ROBOTS; 
EXCEPTION 
    WHEN NO_DATA_FOUND THEN 
        RETURN 0; 
    WHEN OTHERS THEN 
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM); 
END GET_NB_BIG_ROBOTS;/


/* Fonction GET_BEST_SUPPLIER */

CREATE OR REPLACE FUNCTION GET_BEST_SUPPLIER RETURN VARCHAR2 IS
    v_best_supplier_name VARCHAR2(100);
BEGIN
    SELECT supplier_name INTO v_best_supplier_name    /*Sélectionner le nom du meilleur fournisseur basé sur la vue BEST_SUPPLIERS*/
    FROM BEST_SUPPLIERS
    WHERE ROWNUM = 1;                                 /*Récupérer le premier fournisseur (meilleur) basé sur un critère quelconque*/

    RETURN v_best_supplier_name;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;                                                                /*Retourner NULL si aucun fournisseur n'est trouvé*/
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END GET_BEST_SUPPLIER;
/



/* FONCTION OLDEST */

CREATE OR REPLACE FUNCTION GET_OLDEST_WORKER RETURN NUMBER IS
    OLDEST_WORKER_ID NUMBER;
BEGIN
    SELECT worker_id INTO OLDEST_WORKER_ID                                              /*Sélectionne l'identifiant du travailleur le plus ancien parmi tous les travailleurs de toutes les usines*/
    FROM (  
        SELECT worker_id, MIN(start_date) AS min_start_date
        FROM (
            SELECT id AS worker_id, first_day AS start_date
            FROM WORKERS_FACTORY_1
            UNION ALL
            SELECT worker_id, start_date
            FROM WORKERS_FACTORY_2
        )
        GROUP BY worker_id
        ORDER BY min_start_date ASC
    )
    WHERE ROWNUM = 1;

    RETURN OLDEST_WORKER_ID;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;                                                                        /*Si aucune donnée n'est trouvée, retourne NULL*/
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'An error occurred: ' || SQLERRM);
END GET_OLDEST_WORKER;
/





/*################################################################################*/
/*                                     PROCEDURES                                 */
/*################################################################################*/


/* Procédure n1 */

CREATE OR REPLACE PROCEDURE SEED_DATA_WORKERS(
    NB_WORKERS NUMBER,
    FACTORY_ID NUMBER
)
IS
BEGIN
    FOR i IN 1..NB_WORKERS LOOP
        DECLARE
            v_first_name VARCHAR2(100);
            v_last_name VARCHAR2(100);
            v_start_date DATE;
        BEGIN
            v_first_name := 'worker_f_' || i;
            v_last_name := 'worker_l_' || i;
            SELECT TO_DATE(TRUNC(DBMS_RANDOM.VALUE(TO_CHAR(DATE '2065-01-01', 'J'), 
                                                     TO_CHAR(DATE '2070-01-01', 'J'))), 'J')
            INTO v_start_date
            FROM dual;
            
            IF FACTORY_ID = 1 THEN
                INSERT INTO WORKERS_FACTORY_1 (first_name, last_name, age, first_day, last_day)
                VALUES (v_first_name, v_last_name, TRUNC(DBMS_RANDOM.VALUE(20, 60)), v_start_date, NULL);
            ELSIF FACTORY_ID = 2 THEN
                INSERT INTO WORKERS_FACTORY_2 (first_name, last_name, start_date, end_date)
                VALUES (v_first_name, v_last_name, v_start_date, NULL);
            ELSE
                RAISE_APPLICATION_ERROR(-20001, 'Invalid FACTORY_ID');
            END IF;
        END;
    END LOOP;
END SEED_DATA_WORKERS;
/

/* Procédure n2 */

CREATE OR REPLACE PROCEDURE ADD_NEW_ROBOT(MODEL_NAME VARCHAR2) AS
    v_robot_id NUMBER;
    v_factory_id NUMBER;
BEGIN
    INSERT INTO ROBOTS (model)                                          /*Insérer le nouveau robot dans la table ROBOTS et obtenir l'ID généré*/
    VALUES (MODEL_NAME)
    RETURNING id INTO v_robot_id;

    
    BEGIN                                                               /*Sélectionner l'usine avec le moins de robots*/
        SELECT factory_id
        INTO v_factory_id
        FROM (
            SELECT factory_id, COUNT(*) AS num_robots
            FROM ROBOTS_FROM_FACTORY
            GROUP BY factory_id
            ORDER BY num_robots ASC
        )
        WHERE ROWNUM = 1;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN                                         /*Si aucune usine n'est trouvée (cas rare), affecter une usine par défaut (par exemple, 1)*/
            v_factory_id := 1;
    END;

    
    INSERT INTO ROBOTS_FROM_FACTORY (robot_id, factory_id)              /*Insérer l'ID du robot et l'ID de l'usine dans la table ROBOTS_FROM_FACTORY*/
    VALUES (v_robot_id, v_factory_id);

    
    DBMS_OUTPUT.PUT_LINE('New robot with model ' || MODEL_NAME || ' added with ID ' || v_robot_id || ' to factory ' || v_factory_id);   /*Afficher un message de confirmation*/

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);         /*Gestion des erreurs*/
        ROLLBACK;
END ADD_NEW_ROBOT;
/                                                                       /*  à la fin si jamais le code est executé en sqlplus */


/*Procédure n3*/

CREATE OR REPLACE PROCEDURE SEED_DATA_SPARE_PARTS(NB_SPARE_PARTS NUMBER) AS
BEGIN
    FOR i IN 1..NB_SPARE_PARTS LOOP
        INSERT INTO SPARE_PARTS (color, name)
        VALUES (
            CASE MOD(i, 5)
                WHEN 0 THEN 'red'
                WHEN 1 THEN 'gray'
                WHEN 2 THEN 'black'
                WHEN 3 THEN 'blue'
                ELSE 'silver'
            END,
            'Spare Part ' || i
        );
    END LOOP;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE(NB_SPARE_PARTS || ' spare parts added successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
        ROLLBACK;
END;
/

