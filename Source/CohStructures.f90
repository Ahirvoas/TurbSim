!**********************************************************************************************************************************
! LICENSING
! Copyright (C) 2014  National Renewable Energy Laboratory
!
!    This file is part of TurbSim.
!
! Licensed under the Apache License, Version 2.0 (the "License");
! you may not use this file except in compliance with the License.
! You may obtain a copy of the License at
!
!     http://www.apache.org/licenses/LICENSE-2.0
!
! Unless required by applicable law or agreed to in writing, software
! distributed under the License is distributed on an "AS IS" BASIS,
! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
! See the License for the specific language governing permissions and
! limitations under the License.
!
!**********************************************************************************************************************************
MODULE TS_CohStructures

   USE                     NWTC_Library   
use ts_errors
use TS_Profiles
use TS_RandNum


   IMPLICIT                NONE

   REAL(ReKi), PARAMETER   ::  KHT_LES_dT = 0.036335           ! The average time step in the LES test file, used here for the KH test
   REAL(ReKi), PARAMETER   ::  KHT_LES_Zm = 6.35475            ! The non-dimensional z dimension defined in LES test file, used here for the KH test
   

CONTAINS

!=======================================================================
SUBROUTINE CohStr_ReadEventFile( p_CohStr, CTKE, TSclFact, ErrStat, ErrMsg )

      ! This subroutine reads the events definitions from the event data file


   IMPLICIT                NONE


      ! Passed Variables
      
TYPE(CohStr_ParameterType), INTENT(INOUT) :: p_CohStr

REAL(ReKi),                      INTENT(IN)    :: CTKE           ! Predicted maximum CTKE
!REAL(ReKi),                      INTENT(INOUT) :: ScaleVel       ! The shear we're scaling for
!REAL(ReKi),                      INTENT(IN)    :: ScaleWid       ! The height of the wave we're scaling with
REAL(ReKi),                      INTENT(  OUT) :: TsclFact       ! Scale factor for time (h/U0) in coherent turbulence events
INTEGER(IntKi),                  intent(  out) :: ErrStat        ! Error level
CHARACTER(*),                    intent(  out) :: ErrMsg         ! Message describing error

      ! Local variables
REAL(ReKi)              :: MaxEvtCTKE        ! The maximum CTKE in the dataset of events

INTEGER                 :: I              ! DO loop counter
INTEGER                 :: IOS            ! I/O Status
INTEGER                 :: Un             ! I/O Unit

INTEGER(IntKi)                                 :: ErrStat2                         ! Error level (local)
CHARACTER(MaxMsgLen)                           :: ErrMsg2                          ! Message describing error (local)


   ErrStat = ErrID_None
   ErrMsg  = ""
   
   MaxEvtCTKE = 0.0  ! initialize the MAX variable

   CALL GetNewUnit( Un, ErrStat2, ErrMsg2 )
   
   CALL OpenFInpFile ( Un,  p_CohStr%CTEventFile, ErrStat2, ErrMsg2)
      CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'CohStr_ReadEventFile')
      IF (ErrStat >= AbortErrLev) RETURN
   

         ! Read the nondimensional lateral width of the dataset, Ym_max

   CALL ReadVar( Un, p_CohStr%CTEventFile, p_CohStr%Ym_max, "Ym_max", "Nondimensional lateral dataset width", ErrStat2, ErrMsg2)
      CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'CohStr_ReadEventFile')

         ! Read the nondimensional vertical height of the dataset, Zm_max

   CALL ReadVar( Un, p_CohStr%CTEventFile, p_CohStr%Zm_max, "Zm_max", "Nondimensional vertical dataset height", ErrStat2, ErrMsg2)
      CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'CohStr_ReadEventFile')


         ! Read the rest of the header

   CALL ReadVar( Un, p_CohStr%CTEventFile, p_CohStr%NumEvents, "NumEvents", "the number of coherent structures.", ErrStat2, ErrMsg2)
      CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'CohStr_ReadEventFile')
      
      
   IF (ErrStat >= AbortErrLev) THEN
      CLOSE(Un)
      RETURN
   END IF
      

   IF ( p_CohStr%NumEvents > 0 ) THEN


      CALL AllocAry( p_CohStr%EventID,  p_CohStr%NumEvents , 'EventID',  ErrStat2, ErrMsg2); CALL SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,'CohStr_ReadEventFile')
      CALL AllocAry( p_CohStr%EventTS,  p_CohStr%NumEvents , 'EventTS',  ErrStat2, ErrMsg2); CALL SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,'CohStr_ReadEventFile')
      CALL AllocAry( p_CohStr%EventLen, p_CohStr%NumEvents , 'EventLen', ErrStat2, ErrMsg2); CALL SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,'CohStr_ReadEventFile')
      CALL AllocAry( p_CohStr%pkCTKE,   p_CohStr%NumEvents , 'pkCTKE',   ErrStat2, ErrMsg2); CALL SetErrStat(ErrStat2,ErrMsg2,ErrStat,ErrMsg,'CohStr_ReadEventFile')

      IF (ErrStat >= AbortErrLev) THEN
         CLOSE(Un)
         RETURN
      END IF
      
            ! Read the last header lines

      CALL ReadCom( Un, p_CohStr%CTEventFile, 'the fourth header line', ErrStat2, ErrMsg2) ! A blank line
         CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'CohStr_ReadEventFile')  
      CALL ReadCom( Un, p_CohStr%CTEventFile, 'the fifth header line', ErrStat2, ErrMsg2) ! The column heading lines
         CALL SetErrStat(ErrStat2, ErrMsg2, ErrStat, ErrMsg, 'CohStr_ReadEventFile')   


            ! Read the event definitions and scale times by TScale

      DO I=1,p_CohStr%NumEvents

         READ ( Un, *, IOSTAT=IOS )  p_CohStr%EventID(I),  p_CohStr%EventTS(I), p_CohStr%EventLen(I), p_CohStr%pkCTKE(I)

         IF ( IOS /= 0 )  THEN
            CALL SetErrStat(ErrID_Fatal, 'Error reading event '//TRIM( Int2LStr( I ) )//' from the coherent event data file.', ErrStat, ErrMsg, 'CohStr_ReadEventFile')
            CLOSE(UN)
            RETURN
         ENDIF
         MaxEvtCTKE = MAX( MaxEvtCTKE, p_CohStr%pkCTKE(I) )

      ENDDO

      IF ( MaxEvtCTKE > 0.0 ) THEN
            p_CohStr%ScaleVel = MAX( p_CohStr%ScaleVel, SQRT( CTKE / MaxEvtCTKE ) )
            ! Calculate the Velocity Scale Factor, based on the requested maximum CTKE
      ENDIF

         ! Calculate the TimeScaleFactor, based on the Zm_max in the Events file.

      TSclFact = p_CohStr%ScaleWid / (p_CohStr%ScaleVel * p_CohStr%Zm_max)

         ! Scale the time based on TSclFact

      DO I=1,p_CohStr%NumEvents
         p_CohStr%EventLen(I) = p_CohStr%EventLen(I)*TSclFact
      ENDDO

   ELSE

      TSclFact = p_CohStr%ScaleWid / (p_CohStr%ScaleVel * p_CohStr%Zm_max)

   ENDIF  ! FileNum > 0

   CLOSE ( Un )  

END SUBROUTINE CohStr_ReadEventFile
!=======================================================================
SUBROUTINE CohStr_CalcEvents( p_met, p_RNG, p_grid, p_cohStr, Height, OtherSt_RandNum, y_cohStr )

      ! This subroutine calculates what events to use and when to use them.
      ! It computes the number of timesteps in the file, NumCTt.

   IMPLICIT                    NONE

      ! passed variables
TYPE(Meteorology_ParameterType), INTENT(IN)     :: p_met               ! parameters for TurbSim
TYPE(RandNum_ParameterType)    , INTENT(IN)     :: p_RNG           ! parameters for random numbers
TYPE(Grid_ParameterType)       , INTENT(IN)     :: p_grid              ! parameters for grid (specify grid/frequency size)
TYPE(CohStr_ParameterType)     , INTENT(IN)     :: p_CohStr            ! parameters for coherent structures
REAL(ReKi),                      INTENT(IN)     :: Height              ! Height for expected length PDF equation
TYPE(RandNum_OtherStateType),    INTENT(INOUT)  :: OtherSt_RandNum     ! other states for random numbers (next seed, etc)
TYPE(CohStr_OutputType),         INTENT(INOUT)  :: y_CohStr

      ! local variables
REAL(ReKi)                  :: iA                  ! Variable used to calculate IAT
REAL(ReKi)                  :: iB                  ! Variable used to calculate IAT
REAL(ReKi)                  :: iC                  ! Variable used to calculate IAT
REAL(ReKi)                  :: rn                  ! random number
REAL(ReKi)                  :: TEnd                ! End time for the current event
REAL(ReKi)                  :: TStartNext   = 0.0  ! temporary start time for next event
REAL(ReKi)                  :: MaxCTKE             ! Maximum CTKE of events we've picked

INTEGER                     :: IStat               ! Status of memory allocation
INTEGER                     :: NewEvent            ! event number of the new event
INTEGER                     :: NumCompared         ! Number of events we've compared

LOGICAL(1)                  :: Inserted            ! Whether an event was inserted here

TYPE(Event), POINTER        :: PtrCurr  => NULL()  ! Pointer to the current event in the list
TYPE(Event), POINTER        :: PtrNew   => NULL()  ! A new event to be inserted into the list


      ! Compute the mean interarrival time and the expected length of events

   SELECT CASE ( p_met%TurbModel_ID )

      CASE ( SpecModel_NWTCUP, SpecModel_NONE, SpecModel_USRVKM )
         y_CohStr%lambda = -0.000904*p_met%Rich_No + 0.000562*p_CohStr%Uwave + 0.001389
         y_CohStr%lambda = 1.0 / y_CohStr%lambda

         IF ( p_met%TurbModel_ID == SpecModel_NONE ) THEN
            y_CohStr%ExpectedTime = 600.0
         ELSE
            CALL RndModLogNorm( p_RNG, OtherSt_RandNum, y_CohStr%ExpectedTime, Height )
         ENDIF

      CASE ( SpecModel_GP_LLJ, SpecModel_SMOOTH, SpecModel_TIDAL, SpecModel_RIVER) ! HYDRO: added 'TIDAL' and 'RIVER' to the spectral models that get handled this way.
         iA     =        0.001797800 + (7.17399E-10)*Height**3.021144723
         iB     =  EXP(-10.590340100 - (4.92440E-05)*Height**2.5)
         iC     = SQRT(  3.655013599 + (8.91203E-06)*Height**3  )
         y_CohStr%lambda = iA + iB*MIN( (p_CohStr%Uwave**iC), HUGE(iC) )  ! lambda = iA + iB*(WindSpeed**iC)
         y_CohStr%lambda = 1.0 / y_CohStr%lambda

         CALL RndTcohLLJ( p_RNG, OtherSt_RandNum, y_CohStr%ExpectedTime, Height )

      CASE ( SpecModel_WF_UPW )
        y_CohStr%lambda = 0.000529*p_CohStr%Uwave + 0.000365*p_met%Rich_No - 0.000596
        y_CohStr%lambda = 1.0 / y_CohStr%lambda

         CALL RndTcoh_WF( p_RNG, OtherSt_RandNum, y_CohStr%ExpectedTime, SpecModel_WF_UPW )

      CASE ( SpecModel_WF_07D )
         y_CohStr%lambda = 0.000813*p_CohStr%Uwave - 0.002642*p_met%Rich_No + 0.002676
         y_CohStr%lambda = 1.0 / y_CohStr%lambda

         CALL RndTcoh_WF( p_RNG, OtherSt_RandNum, y_CohStr%ExpectedTime, SpecModel_WF_07D )

      CASE ( SpecModel_WF_14D )
         y_CohStr%lambda = 0.001003*p_CohStr%Uwave - 0.00254*p_met%Rich_No - 0.000984
         y_CohStr%lambda = 1.0 / y_CohStr%lambda

         CALL RndTcoh_WF( p_RNG, OtherSt_RandNum, y_CohStr%ExpectedTime, SpecModel_WF_14D )

      CASE DEFAULT
         !This should not happen

   END SELECT

   y_CohStr%ExpectedTime = y_CohStr%ExpectedTime * ( p_grid%UsableTime - p_CohStr%CTStartTime ) / 600.0  ! Scale for use with the amount of time we've been given


!BONNIE: PERHAPS WE SHOULD JUST PUT IN A CHECK THAT TURNS OFF THE COHERENT TIME STEP FILE IF THE
!        CTSTARTTIME IS LESS THAN THE USABLETIME... MAYBE WHEN WE'RE READING THE INPUT FILE...
y_CohStr%ExpectedTime = MAX( y_CohStr%ExpectedTime, REAL(0.0,ReKi) )  ! This occurs if CTStartTime = 0

      ! We start by adding events at random times

   y_CohStr%NumCTEvents = 0                                    ! Number of events = length of our linked list
   y_CohStr%NumCTt      = 0                                    ! Total number of time steps in the events we've picked
   MaxCTKE              = 0.0                                  ! Find the maximum CTKE for the events that we've selected

   y_CohStr%EventTimeSum = 0.0 

   CALL RndExp(p_RNG, OtherSt_RandNum, rn, y_CohStr%lambda)                            ! Assume the last event ended at time zero

   TStartNext = rn / 2.0

   IF ( p_met%KHtest ) THEN
      y_CohStr%ExpectedTime = p_grid%UsableTime     / 2                 ! When testing, add coherent events for half of the record
      TStartNext            = y_CohStr%ExpectedTime / 2                 ! When testing, start about a quarter of the way into the record
   ENDIF

   IF ( TStartNext < p_CohStr%CTStartTime ) THEN
      TStartNext = TStartNext + p_CohStr%CTStartTime           ! Make sure the events start after time specified by CTStartTime
   ENDIF

   IF ( TStartNext > 0 ) y_CohStr%NumCTt = y_CohStr%NumCTt + 1          ! Add a point before the first event

   DO WHILE ( TStartNext < p_grid%UsableTime .AND. y_CohStr%EventTimeSum < y_CohStr%ExpectedTime )

      CALL RndUnif( p_RNG, OtherSt_RandNum, rn )

      NewEvent = INT( rn*( p_CohStr%NumEvents - 1.0 ) ) + 1
      NewEvent = MAX( 1, MIN( NewEvent, p_CohStr%NumEvents ) ) ! take care of possible rounding issues....


      IF ( .NOT. ASSOCIATED ( y_CohStr%PtrHead ) ) THEN

         ALLOCATE ( y_CohStr%PtrHead, STAT=IStat )             ! The pointer %Next is nullified in allocation

         IF ( IStat /= 0 ) THEN
            CALL TS_Abort ( 'Error allocating memory for new event.' )
         ENDIF

         y_CohStr%PtrTail => y_CohStr%PtrHead

      ELSE

         ALLOCATE ( y_CohStr%PtrTail%Next, STAT=IStat )     ! The pointer PtrTail%Next%Next is nullified in allocation

         IF ( IStat /= 0 ) THEN
            CALL TS_Abort ( 'Error allocating memory for new event.' )
         ENDIF

         y_CohStr%PtrTail => y_CohStr%PtrTail%Next                   ! Move the pointer to point to the last record in the list

      ENDIF

      y_CohStr%PtrTail%EventNum     = NewEvent
      y_CohStr%PtrTail%TStart       = TStartNext
      y_CohStr%PtrTail%delt         = p_CohStr%EventLen( NewEvent ) / p_CohStr%EventTS( NewEvent )          ! the average delta time in the event
      y_CohStr%PtrTail%Connect2Prev = .FALSE.

      MaxCTKE              = MAX( MaxCTKE, p_CohStr%pkCTKE( NewEvent ) )
      y_CohStr%NumCTEvents          = y_CohStr%NumCTEvents + 1

      TEnd = TStartNext + p_CohStr%EventLen( NewEvent )


      IF ( p_met%KHtest ) THEN
         TStartNext   = p_grid%UsableTime + TStartNext !TEnd + PtrTail%delt ! Add the events right after each other
      ELSE

         DO WHILE ( TStartNext <= TEnd )

            CALL RndExp(p_RNG, OtherSt_RandNum, rn, y_CohStr%lambda)    ! compute the interarrival time
            TStartNext        = TStartNext + rn !+ EventLen( NewEvent )

         ENDDO

      ENDIF


      IF ( (TStartNext - TEnd) > y_CohStr%PtrTail%delt ) THEN
         y_CohStr%NumCTt = y_CohStr%NumCTt + p_CohStr%EventTS( NewEvent ) + 2                                  ! add a zero-line (essentially a break between events)
      ELSE
         y_CohStr%NumCTt = y_CohStr%NumCTt + p_CohStr%EventTS( NewEvent ) + 1
      ENDIF

      y_CohStr%EventTimeSum     = y_CohStr%EventTimeSum + p_CohStr%EventLen( NewEvent )

   ENDDO

   y_CohStr%NumCTEvents_separate = y_CohStr%NumCTEvents

      ! Next, we start concatenating events until there is no space or we exceed the expected time

   IF ( p_met%TurbModel_ID /= SpecModel_NONE ) THEN

      NumCompared = 0

      DO WHILE ( y_CohStr%EventTimeSum < y_CohStr%ExpectedTime .AND. NumCompared < y_CohStr%NumCTEvents )

         CALL RndUnif( p_RNG, OtherSt_RandNum, rn )

         NewEvent = INT( rn*( p_CohStr%NumEvents - 1.0 ) ) + 1
         NewEvent = MAX( 1, MIN( NewEvent, p_CohStr%NumEvents ) )    ! take care of possible rounding issues....

         NumCompared = 0
         Inserted    = .FALSE.

         DO WHILE ( NumCompared < y_CohStr%NumCTEvents .AND. .NOT. Inserted )

            IF ( .NOT. ASSOCIATED ( PtrCurr ) ) THEN        ! Wrap around to the beginning of the list
               PtrCurr => y_CohStr%PtrHead
            ENDIF


               ! See if the NewEvent fits between the end of event pointed to by PtrCurr and the
               ! beginning of the event pointed to by PtrCurr%Next

            IF ( ASSOCIATED( PtrCurr%Next ) ) THEN
               TStartNext = PtrCurr%Next%TStart
            ELSE !We're starting after the last event in the record
               TStartNext = p_grid%UsableTime + 0.5 * p_CohStr%EventLen( NewEvent )  ! We can go a little beyond the end...
            ENDIF

            IF ( TStartNext - (PtrCurr%TStart + p_CohStr%EventLen( PtrCurr%EventNum ) + PtrCurr%delt) > p_CohStr%EventLen( NewEvent ) ) THEN

               Inserted = .TRUE.

               ALLOCATE ( PtrNew, STAT=IStat )           ! The pointer %Next is nullified in allocation

               IF ( IStat /= 0 ) THEN
                  CALL TS_Abort ( 'Error allocating memory for new event.' )
               ENDIF

               PtrNew%EventNum      = NewEvent
               PtrNew%TStart        = PtrCurr%TStart + p_CohStr%EventLen( PtrCurr%EventNum )
               PtrNew%delt          = p_CohStr%EventLen( NewEvent ) / p_CohStr%EventTS( NewEvent )          ! the average delta time in the event
               PtrNew%Connect2Prev  = .TRUE.

               PtrNew%Next  => PtrCurr%Next
               PtrCurr%Next => PtrNew
               PtrCurr      => PtrCurr%Next    ! Let's try to add the next event after the other events

               MaxCTKE              = MAX( MaxCTKE, p_CohStr%pkCTKE( NewEvent ) )
               y_CohStr%NumCTEvents          = y_CohStr%NumCTEvents + 1
               y_CohStr%NumCTt               = y_CohStr%NumCTt + p_CohStr%EventTS( NewEvent )  ! there is no break between events
                                   !(we may have one too many NumCTt here, so we'll deal with it when we write the file later)
               y_CohStr%EventTimeSum         = y_CohStr%EventTimeSum + p_CohStr%EventLen( NewEvent )


            ELSE

               NumCompared = NumCompared + 1

            ENDIF

            PtrCurr => PtrCurr%Next

         ENDDO ! WHILE (NumCompared < NumCTEvents .AND. .NOT. Inserted)

      ENDDO ! WHILE (EventTimeSum < ExpectedTime .AND. NumCompared < NumCTEvents)

   ENDIF ! SpecModel /= SpecModel_NONE

   IF ( y_CohStr%NumCTt > 0 ) THEN
      y_CohStr%EventTimeStep = y_CohStr%EventTimeSum / y_CohStr%NumCTt                                          ! Average timestep of coherent event data
   ELSE
      y_CohStr%EventTimeStep = 0.0
   ENDIF


END SUBROUTINE CohStr_CalcEvents
!=======================================================================
!> This subroutine writes the coherent events CTS file
SUBROUTINE CohStr_WriteCTS(p_met, p_RNG, p_grid, p_CohStr, OtherSt_RandNum, y_CohStr, RootName, ErrStat, ErrMsg)
use TS_RandNum
use TSMods, only: uhub, us, p

   TYPE(Meteorology_ParameterType), INTENT(IN)     :: p_met               ! parameters for TurbSim
   TYPE(RandNum_ParameterType)    , INTENT(IN)     :: p_RNG               ! parameters for random numbers
   TYPE(Grid_ParameterType)       , INTENT(IN)     :: p_grid              ! parameters for grid (specify grid/frequency size)
   TYPE(CohStr_ParameterType)     , INTENT(INOUT)  :: p_CohStr            ! parameters for coherent structures
   TYPE(RandNum_OtherStateType),    INTENT(INOUT)  :: OtherSt_RandNum     ! other states for random numbers (next seed, etc)
   TYPE(CohStr_OutputType),         INTENT(INOUT)  :: y_CohStr


   INTEGER(IntKi),                  intent(  out) :: ErrStat              ! Error level
   CHARACTER(*),                    intent(  out) :: ErrMsg               ! Message describing error
   CHARACTER(*),                    intent(in   ) :: RootName             ! Rootname of output file


   
   REAL(ReKi)                                     :: TmpRndNum                       ! A temporary variable holding a random variate
   REAL(ReKi)                                     :: TsclFact                        ! Scale factor for time (h/U0) in coherent turbulence events

   
   ErrStat = ErrID_None
   ErrMsg  = ""

   CALL WrScr ( ' Generating coherent turbulent time step file "'//TRIM( RootName )//'.cts"' )
   
   
   p_CohStr%ScaleWid = p_grid%RotorDiameter * p_CohStr%DistScl           !  This is the scaled height of the coherent event data set
   p_CohStr%Zbottom  = p_grid%HubHt - p_CohStr%CTLz*p_CohStr%ScaleWid    !  This is the height of the bottom of the wave in the scaled/shifted coherent event data set
   
   p_CohStr%Uwave    = getVelocity(UHub,p_grid%HubHt,p_CohStr%Zbottom + 0.5*p_CohStr%ScaleWid, p_grid%RotorDiameter)                 ! WindSpeed at center of wave
   
   !-------------------------
   ! compute ScaleVel:
   !-------------------------

   IF ( p_met%KHtest ) THEN      
         ! for LES test case....
      p_CohStr%ScaleVel = p_CohStr%ScaleWid * KHT_LES_dT /  KHT_LES_Zm    
      p_CohStr%ScaleVel = 50 * p_CohStr%ScaleVel                  ! We want 25 hz bandwidth so multiply by 50
   ELSE
      p_CohStr%ScaleVel =  getVelocity(UHub,p_grid%HubHt,p_CohStr%Zbottom+p_CohStr%ScaleWid,p_grid%RotorDiameter) &  ! Velocity at the top of the wave
                         - getVelocity(UHub,p_grid%HubHt,p_CohStr%Zbottom,                  p_grid%RotorDiameter)    ! Shear across the wave
      p_CohStr%ScaleVel = 0.5 * p_CohStr%ScaleVel                                                                               ! U0 is half the difference between the top and bottom of the billow
      
      
         ! If the coherent structures do not cover the whole disk, increase the shear

      IF ( p_CohStr%DistScl < 1.0 ) THEN ! Increase the shear by up to two when the wave is half the size of the disk...
         CALL RndUnif( p_RNG, OtherSt_RandNum, TmpRndNum ) !returns TmpRndNum, a random variate
         p_CohStr%ScaleVel = p_CohStr%ScaleVel * ( 1.0 + TmpRndNum * (1 - p_CohStr%DistScl) / p_CohStr%DistScl )
      ENDIF

         !Apply a scaling factor to account for short inter-arrival times getting wiped out due to long events

      p_CohStr%ScaleVel =  p_CohStr%ScaleVel*( 1.0 + 323.1429 * EXP( -MAX(p_CohStr%Uwave,10.0) / 2.16617 ) )
            
   ENDIF

   IF (p_CohStr%ScaleVel < 0. ) THEN
      CALL TS_Warn( ' A coherent turbulence time step file cannot be generated with negative shear.', US )
      p%WrFile(FileExt_CTS) = .FALSE.
      RETURN
   ENDIF
      

   !-------------------------
   ! compute maximum predicted CTKE:
   !-------------------------
         
   SELECT CASE ( p_met%TurbModel_ID )
         
      CASE ( SpecModel_NWTCUP,  SpecModel_NONE, SpecModel_USRVKM )
            
         IF (p_met%KHtest) THEN
            y_CohStr%CTKE = 30.0 !Scale for large coherence
            CALL RndNWTCpkCTKE( p_RNG, OtherSt_RandNum, y_CohStr%CTKE )
         ELSE    
               
               ! Increase the Scaling Velocity for computing U,V,W in AeroDyn
               ! These numbers are based on LIST/ART data (58m-level sonic anemometer)

            y_CohStr%CTKE =  0.616055*p_met%Rich_No - 0.242143*p_CohStr%Uwave + 23.921801*p_CohStr%WSig - 11.082978
            
               ! Add up to +/- 10% or +/- 6 m^2/s^2 (uniform distribution)
            CALL RndUnif( p_RNG, OtherSt_RandNum, TmpRndNum )
            y_CohStr%CTKE = MAX( y_CohStr%CTKE + (2.0 * TmpRndNum - 1.0) * 6.0, 0.0 )

            IF ( y_CohStr%CTKE > 0.0 ) THEN
               IF ( y_CohStr%CTKE > 20.0)  THEN    ! Correct with residual
                  y_CohStr%CTKE = y_CohStr%CTKE + ( 0.11749127 * (y_CohStr%CTKE**1.369025) - 7.5976449 )
               ENDIF

               IF ( y_CohStr%CTKE >= 30.0 .AND. p_met%Rich_No >= 0.0 .AND. p_met%Rich_No <= 0.05 ) THEN
                  CALL RndNWTCpkCTKE( p_RNG, OtherSt_RandNum, y_CohStr%CTKE )
               ENDIF
            ENDIF
                  
         ENDIF !p_met%KHtest
               
      CASE ( SpecModel_GP_LLJ, SpecModel_SMOOTH, SpecModel_TIDAL, SpecModel_RIVER )          

         y_CohStr%CTKE = pkCTKE_LLJ( p_grid%Zbottom+0.5*p_CohStr%ScaleWid, p_met%ZL, p_met%UStar )
               
      CASE ( SpecModel_WF_UPW )
         y_CohStr%CTKE = -2.964523*p_met%Rich_No - 0.207382*p_CohStr%Uwave + 25.640037*p_CohStr%WSig - 10.832925
               
      CASE ( SpecModel_WF_07D )
         y_CohStr%CTKE = 9.276618*p_met%Rich_No + 6.557176*p_met%Ustar + 3.779539*p_CohStr%WSig - 0.106633

         IF ( (p_met%Rich_No > -0.025) .AND. (p_met%Rich_No < 0.05) .AND. (p_met%Ustar > 1.0) .AND. (p_met%Ustar < 1.56) ) THEN
            CALL RndpkCTKE_WFTA( p_RNG, OtherSt_RandNum, TmpRndNum )  ! Add a random residual
            y_CohStr%CTKE = y_CohStr%CTKE + TmpRndNum
         ENDIF
               
               
      CASE ( SpecModel_WF_14D )
         y_CohStr%CTKE = 1.667367*p_met%Rich_No - 0.003063*p_CohStr%Uwave + 19.653682*p_CohStr%WSig - 11.808237
               
      CASE DEFAULT   ! This case should not happen            
         CALL TS_Abort( 'Invalid turbulence model in coherent structure analysis.' )            
               
   END SELECT                    

   y_CohStr%CTKE   = MAX( y_CohStr%CTKE, 1.0 )     ! make sure CTKE is not negative and, so that we don't divide by zero in ReadEventFile, set it to some arbitrary low number   
   
   !-------------------------
   ! Read and allocate coherent event start times and lengths, calculate TSclFact:
   !-------------------------   
   CALL CohStr_ReadEventFile( p_CohStr, y_CohStr%CTKE, TSclFact, ErrStat, ErrMsg ) !p_CohStr%%ScaleWid, p_CohStr%ScaleVel
   IF (ErrStat >= AbortErrLev) RETURN

   
   CALL CohStr_CalcEvents( p_met, p_RNG, p_grid, p_CohStr,  p_CohStr%Zbottom+0.5*p_CohStr%ScaleWid, OtherSt_RandNum, y_cohStr) 
         

   !-------------------------
   ! Write the file:
   !-------------------------
   
   CALL CohStr_WriteEvents ( TSclFact )

   !-------------------------
   ! Deallocate the coherent event arrays.
   !-------------------------

   IF ( ALLOCATED( p_CohStr%EventID   ) )  DEALLOCATE( p_CohStr%EventID   )
   IF ( ALLOCATED( p_CohStr%EventTS   ) )  DEALLOCATE( p_CohStr%EventTS   )
   IF ( ALLOCATED( p_CohStr%EventLen  ) )  DEALLOCATE( p_CohStr%EventLen  )
   IF ( ALLOCATED( p_CohStr%pkCTKE    ) )  DEALLOCATE( p_CohStr%pkCTKE    )
   
         
END SUBROUTINE CohStr_WriteCTS
!=======================================================================
FUNCTION pkCTKE_LLJ(Ht, ZL, UStar)

   use tsmods, only: p
   use tsmods, only: OtherSt_RandNum
   
use TurbSim_Types

IMPLICIT                 NONE

REAL(ReKi), INTENT(IN)   :: Ht                                       ! The height at the billow center
REAL(ReKi), INTENT(IN)   :: ZL                                       ! The height at the billow center
REAL(ReKi), INTENT(IN)   :: Ustar                                    ! The height at the billow center


REAL(ReKi)               :: A                                        ! A constant/offset term in the pkCTKE calculation
REAL(ReKi)               :: A_uSt                                    ! The scaling term for Ustar
REAL(ReKi)               :: A_zL                                     ! The scaling term for z/L
REAL(ReKi)               :: pkCTKE_LLJ                               ! The max CTKE expected for LLJ coh structures
REAL(ReKi)               :: rndCTKE                                  ! The random residual

REAL(ReKi), PARAMETER    :: RndParms(5) = (/0.252510525, -0.67391279, 2.374794977, 1.920555797, -0.93417558/) ! parameters for the Pearson IV random residual
REAL(ReKi), PARAMETER    :: z_Ary(4)    = (/54., 67., 85., 116./)    ! Aneomoeter heights

INTEGER                  :: Zindx_mn (1)


   Zindx_mn = MINLOC( ABS(z_Ary-Ht) )

   SELECT CASE ( Zindx_mn(1) )
      CASE ( 1 )  ! 54 m
         A     = -0.051
         A_zL  = -0.0384
         A_uSt =  9.9710

      CASE ( 2 )  ! 67 m
         A     = -0.054
         A_zL  = -0.1330
         A_uSt = 10.2460

      CASE ( 3 )  ! 85 m
         A     = -0.062
         A_zL  = -0.1320
         A_uSt = 10.1660

      CASE ( 4 )  !116 m
         A     = -0.092
         A_zL  = -0.3330
         A_uSt = 10.7640

      CASE DEFAULT !This should not occur
         CALL TS_Abort( 'Error in pkCTKE_LLJ():: Height index is invalid.' )
   END SELECT

   CALL RndPearsonIV( p%RNG, OtherSt_RandNum, rndCTKE, RndParms, (/ -10.0_ReKi, 17.5_ReKi /) )

   pkCTKE_LLJ = MAX(0.0, A + A_uSt*UStar + A_zL*ZL + rndCTKE)

END FUNCTION pkCTKE_LLJ
!=======================================================================
SUBROUTINE CohStr_WriteEvents( TScale )

    ! This subroutine writes the events as calculated in CalcEvents.

USE                     TSMods

IMPLICIT                NONE

      ! Passed Variables

REAL(ReKi), INTENT(IN)  :: TScale                 ! Time scaling factor


      ! Local Variables

REAL(ReKi)              :: CurrentTime = 0.0      ! the current time (in seconds)
REAL(ReKi)              :: CTTime                 ! Time from beginning of event file
REAL(ReKi)              :: deltaTime = 0.0        ! difference between two time steps in the event files

INTEGER                 :: FileNum                ! File Number in the event file
INTEGER                 :: IE                     ! Loop counter for event number
INTEGER                 :: IStat                  ! Status of file read
INTEGER                 :: IT                     ! Loop counter for time step

INTEGER(IntKi)          :: UnIn                   ! I/O Unit for input file
INTEGER(IntKi)          :: UnOut                  ! I/O Unit for output file



CHARACTER(200)          :: InpFile                ! Name of the input file
TYPE (Event), POINTER   :: PtrCurr  => NULL()     ! Pointer to the current event


   CALL GetNewUnit( UnOut )
   CALL OpenFOutFile ( UnOut, TRIM( p%RootName )//'.cts' ) 

   CALL GetNewUnit( UnIn )
   
   
IF (DEBUG_OUT) THEN
   WRITE (UD,'(/,A)' ) 'Computed Coherent Events'
   WRITE (UD,*) 'Event#     Start Time        End Time'
ENDIF


      ! Write event data to the time step output file (opened at the beginnig)

   WRITE (UnOut, "( A14,   ' = FileType')")     p_CohStr%CTExt
   WRITE (UnOut, "( G14.7, ' = ScaleVel')")     p_CohStr%ScaleVel
   WRITE (UnOut, "( G14.7, ' = MHHWindSpeed')") UHub
   WRITE (UnOut, "( G14.7, ' = Ymax')")         p_CohStr%ScaleWid*p_CohStr%Ym_max/p_CohStr%Zm_max
   WRITE (UnOut, "( G14.7, ' = Zmax')")         p_CohStr%ScaleWid
   WRITE (UnOut, "( G14.7, ' = DistScl')")      p_CohStr%DistScl
   WRITE (UnOut, "( G14.7, ' = CTLy')")         p_CohStr%CTLy
   WRITE (UnOut, "( G14.7, ' = CTLz')")         p_CohStr%CTLz
   WRITE (UnOut, "( G14.7, ' = NumCTt')")       y_CohStr%NumCTt


   PtrCurr => y_CohStr%PtrHead


   DO IE = 1,y_CohStr%NumCTEvents

      IF ( .NOT. ASSOCIATED ( PtrCurr ) ) EXIT     ! This shouldn't be necessary, given the way we created the list


      IF ( .NOT. PtrCurr%Connect2Prev ) THEN

         IF ( CurrentTime < PtrCurr%TStart ) THEN

            WRITE ( UnOut, '(G14.7,1x,I5.5)') CurrentTime, 0     ! Print end of previous event

            y_CohStr%NumCTt = y_CohStr%NumCTt - 1  ! Let's make sure the right number of points have been written to the file.

            IF ( CurrentTime < PtrCurr%TStart - PtrCurr%delt ) THEN  !This assumes a ramp of 1 delta t for each structure....

               WRITE ( UnOut, '(G14.7,1x,I5.5)') MAX(PtrCurr%TStart - PtrCurr%delt, REAL(0.0, ReKi) ), 0
               y_CohStr%NumCTt = y_CohStr%NumCTt - 1

            ENDIF

         ENDIF

      ENDIF  ! NOT Connect2Prev


      WRITE ( InpFile, '(I5.5)' ) p_CohStr%EventID( PtrCurr%EventNum )
      InpFile = TRIM( p_CohStr%CTEventPath )//PathSep//'Event'//TRIM( InpFile)//'.dat'

      CALL OpenFInpFile( UnIn, InpFile )


      DO IT = 1,p_CohStr%EventTS( PtrCurr%EventNum )

         READ  ( UnIn, *, IOSTAT=IStat ) FileNum, CTTime, deltaTime

         IF (IStat /= 0) THEN
            CALL TS_Abort( 'Error reading event file'//TRIM( InpFile ) )
         ENDIF

         CurrentTime = PtrCurr%TStart + CTTime*TScale

         WRITE ( UnOut, '(G14.7,1x,I5.5)') CurrentTime, FileNum
         y_CohStr%NumCTt = y_CohStr%NumCTt - 1

      ENDDO    ! IT: Event timestep


      CLOSE ( UnIn )


         ! Add one (delta time) space between events

      CurrentTime = CurrentTime + deltaTime*TScale

IF (DEBUG_OUT) THEN
   WRITE ( UD,'(I6, 2(2x,F14.5))' ) PtrCurr%EventNum, PtrCurr%TStart, CurrentTime
ENDIF

      PtrCurr => PtrCurr%Next

!bjj deallocate the linked list!!!!

   ENDDO !IE: number of events

   WRITE ( UnOut, '(G14.7,1x,I5.5)') CurrentTime, 0     !Add the last line
   y_CohStr%NumCTt = y_CohStr%NumCTt - 1

      ! Let's append zero lines at the end of the file if we haven't output NumCTt lines, yet.
      ! We've subtracted from NumCTt every time we wrote a line so now the number in NumCTt is
      ! how many lines short we are.

   IF ( deltaTime > 0 ) THEN
      deltaTime = deltaTime*TScale
   ELSE
      deltaTime = 0.5
   ENDIF

   DO IE = 1, y_CohStr%NumCTt  ! Write zeros at the end if we happened to insert an event that overwrote one of our zero lines
      CurrentTime = CurrentTime + deltaTime
      WRITE ( UnOut, '(G14.7,1x,I5.5)') CurrentTime, 0
   ENDDO

   CLOSE ( UnOut )

END SUBROUTINE CohStr_WriteEvents
!=======================================================================
END MODULE TS_CohStructures
