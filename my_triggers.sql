/* TRIGGER 1 */
CREATE OR REPLACE TRIGGER insert_worker_all_workers_elapsed
INSTEAD OF INSERT ON ALL_WORKERS_ELAPSED
FOR EACH ROW
BEGIN
    IF :NEW.start_date IS NOT NULL THEN
        -- Insertion dans WORKERS_FACTORY_2
        INSERT INTO WORKERS_FACTORY_2 (first_name, last_name, start_date)
        VALUES (:NEW.first_name, :NEW.last_name, :NEW.start_date);
    ELSE
        INSERT INTO WORKERS_FACTORY_1 (first_name, last_name, age, first_day, last_day)
        VALUES (:NEW.first_name, :NEW.last_name, :NEW.age, SYSDATE, NULL);
    END IF;
END;
/

/* TRIGGER 2 */
CREATE OR REPLACE TRIGGER TRG_INSERT_AUDIT_ROBOT
AFTER INSERT ON ROBOTS
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_ROBOT (robot_id, created_at) VALUES (:NEW.id, SYSDATE);                   /*Insérer la nouvelle entrée dans la table AUDIT_ROBOT avec la date d'ajout actuelle*/
END;
/


/* TRIGGER 3 */
CREATE OR REPLACE TRIGGER TRG_PREVENT_MODIFICATION_ROBOTS_FROM_FACTORY
BEFORE INSERT OR UPDATE OR DELETE ON ROBOTS_FROM_FACTORY
FOR EACH ROW
DECLARE
    v_num_factories NUMBER;
    v_num_workers_tables NUMBER;
BEGIN                                                                                           /*Compter le nombre d'usines dans la table FACTORIES*/
    SELECT COUNT(*) INTO v_num_factories FROM FACTORIES;

    SELECT COUNT(*) INTO v_num_workers_tables                                                   /*Compter le nombre de tables de travailleurs respectant le format WORKERS_FACTORY_<N>*/
    FROM user_tables
    WHERE table_name LIKE 'WORKERS_FACTORY\_%' ESCAPE '\';                                      /*Vérifier si le nombre d'usines est égal au nombre de tables de travailleurs*/
    IF v_num_factories <> v_num_workers_tables THEN                                             /*Lever une erreur si la condition n'est pas respectée*/
        RAISE_APPLICATION_ERROR(-20001, 'Modification not allowed: Number of factories does not match the number of workers tables.');
    END IF;
END;
/



/* TRIGGER 4 */
CREATE OR REPLACE TRIGGER TRG_CALCULATE_DURATION
BEFORE INSERT OR UPDATE OF last_day ON WORKERS_FACTORY_1
FOR EACH ROW
DECLARE
    v_duration NUMBER;
BEGIN
    IF :NEW.last_day IS NOT NULL THEN                                              /*Calculer la durée en jours entre la date de départ et la date d'arrivée*/
        v_duration := ROUND((:NEW.last_day - :NEW.first_day), 2);
    
        BEGIN                                                                      /*Vérifier si la colonne duration n'existe pas encore dans la table*/
            EXECUTE IMMEDIATE 'ALTER TABLE WORKERS_FACTORY_1 ADD (duration NUMBER)';
        EXCEPTION
            WHEN OTHERS THEN
                NULL;                                                               /*La colonne existe déjà, pas besoin de la créer*/
        END;                                                                        /*Ne pas mettre à jour la colonne duration ici*/
    END IF;
END;
/

